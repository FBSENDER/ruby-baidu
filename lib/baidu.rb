# encoding: utf-8
require 'nokogiri'
require 'json'
require 'addressable/uri'
require 'httparty'
class SearchEngine
   #是否收录
    def initialize(perpage = 100)
        @perpage = perpage
    end
    def indexed?(url)
        URI(url)
        result = query(url)
        return result.has_result?
    end
end
class SearchResult
    def initialize(body,baseuri,pagenumber=nil)
        @body = Nokogiri::HTML body
        @baseuri = baseuri
        # @host = URI(baseuri).host
        if pagenumber.nil?
            @pagenumber = 1
        else
            @pagenumber = pagenumber
        end
    end
    def whole
        {
            'ads_top'=>ads_top,
            'ads_right'=>ads_right,
            'ads_bottom'=>ads_bottom,
            'ranks'=>ranks
        }
    end
    #返回当前页中host满足条件的结果
    def ranks_for(specific_host)
        host_ranks = Hash.new
        ranks.each do |id,line|
            if specific_host.class == Regexp
                host_ranks[id] = line if line['host'] =~ specific_host
            elsif specific_host.class == String
                host_ranks[id] = line if line['host'] == specific_host
            end
        end
        host_ranks
    end
    #return the top rank number from @ranks with the input host
    def rank(host)#on base of ranks
        ranks.each do |id,line|
            id = id.to_i
            if host.class == Regexp
                return id if line['host'] =~ host
            elsif host.class == String
                return id if line['host'] == host
            end
        end
        return nil
    end
end

class Qihoo < SearchEngine
    Host = 'www.so.com'
    #基本查询, 相当于在搜索框直接数据关键词查询
    def query(wd)
        #用原始路径请求
        uri = URI.join("http://#{Host}/",URI.encode('s?q='+wd)).to_s
        body = HTTParty.get(uri)
        #如果请求地址被跳转,重新获取当前页的URI,可避免翻页错误
        uri = URI.join("http://#{Host}/",body.request.path).to_s
        QihooResult.new(body,uri)
    end
end

class QihooResult < SearchResult
    Host = 'www.so.com'
    #返回所有当前页的排名结果
    def ranks
        return @ranks unless @ranks.nil?
        @ranks = Hash.new
        id = (@pagenumber - 1) * 10
        @body.xpath('//li[@class="res-list"]').each do |li|
            a = li.search("h3/a").first
            url = li.search("cite")
            next if a['data-pos'].nil?
            id += 1
            text = a.text.strip
            href = a['href']
            url = url.first.text
            host = Addressable::URI.parse(URI.encode("http://#{url}")).host
            @ranks[id.to_s] = {'href'=>"http://so.com#{href}",'text'=>text,'host'=>host}
        end
        @ranks
    end
    def ads_top
        id = 0
        result = []
        @body.search("//ul[@id='djbox']/li").each do |li|
            id+=1
            title = li.search("a").first.text
            href = li.search("cite").first.text.downcase
            host = Addressable::URI.parse(URI.encode(href)).host
            result[id] = {'title'=>title,'href'=>href,'host'=>host}
        end
        result
    end
    def ads_bottom
        []
    end
    def ads_right
        id = 0
        result = []
        @body.search("//ul[@id='rightbox']/li").each do |li|
            id += 1
            title = li.search("a").first.text
            href = li.search("cite").first.text.downcase
            host = Addressable::URI.parse(URI.encode(href)).host
            result[id] = {'title'=>title,'href'=>href,'host'=>host}
        end
        result
    end
    def related_keywords
        []
    end
    #下一页
    def next
        next_href = @body.xpath('//a[@id="snext"]')
        return false if next_href.empty?
        next_href = next_href.first['href']
        next_href = URI.join(@baseuri,next_href).to_s
        # next_href = URI.join("http://#{@host}",next_href).to_s
        next_body = HTTParty.get(next_href).body
        return QihooResult.new(next_body,next_href,@pagenumber+1)
        #@page = MbaiduResult.new(Mechanize.new.click(@page.link_with(:text=>/下一页/))) unless @page.link_with(:text=>/下一页/).nil?
    end
    #有结果
    def has_result?
        !@body.search('//div[@id="main"]/h3').text().include?'没有找到该URL'
    end
end

class Mbaidu < SearchEngine
    BaseUri = 'http://m.baidu.com/s?'
    headers = {
        "User-Agent" => 'Mozilla/5.0 (iPhone; U; CPU iPhone OS 4_3_2 like Mac OS X; en-us) AppleWebKit/533.17.9 (KHTML, like Gecko) Version/5.0.2 Mobile/8H7 Safari/6533.18.5'
    }
    Options = {:headers => headers}

    #基本查询,相当于从搜索框直接输入关键词查询
    def query(wd)
        queryStr = "word=#{wd}"
        uri = URI.encode((BaseUri + queryStr))
        begin
            res = HTTParty.get(uri,Options)
            MbaiduResult.new(res,uri)
        rescue Exception => e
            warn "#{uri} fetch error: #{e.to_s}"
            return false
        end
    end
end
class MbaiduResult < SearchResult
    def initialize(body,baseuri,pagenumber=nil)
        @body = Nokogiri::HTML body
        @baseuri = baseuri
        if pagenumber.nil?
            @pagenumber = 1
        else
            @pagenumber = pagenumber
        end
    end

    #返回当前页所有查询结果
    def ranks
        #如果已经赋值说明解析过,不需要重新解析,直接返回结果
        return @ranks unless @ranks.nil?
        @ranks = Hash.new
        @body.xpath('//div[@class="result"]').each do |result|
            href,text,host,is_mobile = '','','',false
            a = result.search("a").first
            is_mobile = true unless a.search("img").empty?
            host = result.search('[@class="site"]').first
            next if host.nil?
            host = host.text
            href = a['href']
            text = a.text
            id = href.scan(/&order=(\d+)&/)
            if id.empty?
                id = nil
            else
                id = id.first.first.to_i
                id = (@pagenumber-1)*10+id
            end
=begin
            result.children.each do |elem|
                if elem.name == 'a'
                    href = elem['href']
                    id = elem.text.match(/^\d+/).to_s.to_i
                    text = elem.text.sub(/^\d+/,'')
                    text.sub!(/^\u00A0/,'')
                elsif elem['class'] == 'abs'
                    elem.children.each do |elem2|
                        if elem2['class'] == 'site'
                            host = elem2.text
                            break
                        end
                    end
                elsif elem['class'] == 'site'
                    host == elem['href']
                end
            end
=end

            @ranks[id.to_s] = {'href'=>href,'text'=>text,'is_mobile'=>is_mobile,'host'=>host.sub(/\u00A0/,'')}
        end
        @ranks
    end
    def ads_top
        id = 0
        result = []
        @body.search("div[@class='ec_wise_ad']/div").each do |div|
            id += 1
            href = div.search("span[@class='ec_site']").first.text
            href = "http://#{href}"
            title = div.search("a/text()").text.strip
            host = Addressable::URI.parse(URI.encode(href)).host
            result[id] = {'title'=>title,'href'=>href,'host'=>host}
        end
        result
    end
    def ads_right
        []
    end
    def ads_bottom
        []
    end
    def related_keywords
        []
    end
=begin
    #返回当前页中,符合host条件的结果
    def ranks_for(specific_host)
        host_ranks = Hash.new
        ranks.each do |id,line|
            if specific_host.class == Regexp
                host_ranks[id] = line if line['host'] =~ specific_host
            elsif specific_host.class == String
                host_ranks[id] = line if line['host'] == specific_host
            end
        end
        host_ranks
    end
    #return the top rank number from @ranks with the input host
    def rank(host)#on base of ranks
        ranks.each do |id,line|
            id = id.to_i
            if host.class == Regexp
                return id if line['host'] =~ host
            elsif host.class == String
                return id if line['host'] == host
            end
        end
        return nil
    end
=end
    #下一页
    def next
        nextbutton = @body.xpath('//a[text()="下一页"]').first
        return nil if nextbutton.nil?
        url = nextbutton['href']
        url = URI.join(@baseuri,url).to_s
        body = HTTParty.get(url)
        return MbaiduResult.new(body,url,@pagenumber+1)
    end

end
class Baidu < SearchEngine
    BaseUri = 'http://www.baidu.com/s?'
    def suggestions(wd)
        json = HTTParty.get("http://suggestion.baidu.com/su?wd=#{URI.encode(wd)}&cb=callback").body.force_encoding('GBK').encode("UTF-8")
        m = /\[([^\]]*)\]/.match json
        return JSON.parse m[0]
    end
    #to find out the real url for something lik 'www.baidu.com/link?url=7yoYGJqjJ4zBBpC8yDF8xDhctimd_UkfF8AVaJRPKduy2ypxVG18aRB5L6D558y3MjT_Ko0nqFgkMoS'
    def url(id)
      a = Mechanize.new
      a.redirect_ok=false
      return a.head("http://www.baidu.com/link?url=#{id}").header['location']
    end

=begin
    def extend(words,level=3,sleeptime=1)
        level = level.to_i - 1
        words = [words] unless words.respond_to? 'each'

        extensions = Array.new
        words.each do |word|
            self.query(word)
            extensions += related_keywords
            extensions += suggestions(word)
            sleep sleeptime
        end
        extensions.uniq!
        return extensions if level < 1
        return extensions + extend(extensions,level)
    end
=end

    def popular?(wd)
        return HTTParty.get("http://index.baidu.com/main/word.php?word=#{URI.encode(wd.encode("GBK"))}").body.include?"boxFlash"
    end

    def query(wd)
        q = Array.new
        q << "wd=#{wd}"
        q << "rn=#{@perpage}"
        queryStr = q.join("&")
        #uri = URI.encode((BaseUri + queryStr).encode('GBK'))
        uri = URI.encode((BaseUri + queryStr))
        begin
            # @page = @a.get uri
            @page = HTTParty.get uri
            BaiduResult.new(@page,uri)
        rescue Net::HTTP::Persistent::Error
            warn "[timeout] #{uri}"
            return false
        end
=begin
        query = "#{query}"
        @uri = BaseUri+URI.encode(query.encode('GBK'))
        @page = @a.get @uri
        self.clean
        @number = self.how_many
        @maxpage = (@number / @perpage.to_f).round
        @maxpage =10 if @maxpage>10
        @currpage =0
=end
    end

    #site:xxx.yyy.com
    def how_many_pages(host)
        query("site:#{host}").how_many
    end

    #domain:xxx.yyy.com/path/file.html
    def how_many_links(uri)
        query("domain:\"#{uri}\"").how_many
    end

    #site:xxx.yyy.com inurl:zzz
    def how_many_pages_with(host,string)
        query("site:#{host} inurl:#{string}").how_many
    end

=begin
    private
    def clean
        @page.body.force_encoding('GBK')
        @page.body.encode!('UTF-8',:invalid => :replace, :undef => :replace, :replace => "")
        @page.body.gsub! ("[\U0080-\U2C77]+") #mechanize will be confuzed without removing the few characters
    end
=end
end

class BaiduResult < SearchResult
    def initialize(page,baseuri,pagenumber=1)
        @page = Nokogiri::HTML page
        @baseuri = baseuri
        @pagenumber = pagenumber
        # raise ArgumentError 'should be Mechanize::Page' unless page.class == Mechanize::Page
        # @page = page
    end

    def ranks
        return @ranks unless @ranks.nil?
        @ranks = Hash.new
        @page.search("//table[@class=\"result\"]|//table[@class=\"result-op\"]").each do |table|
            id = table['id']
            @ranks[id] = Hash.new
            url = table.search("[@class=\"g\"]").first
            url = url.text unless url.nil?
            a = table.search("a").first
            next if a.nil?
            @ranks[id]['text'] = a.text
            @ranks[id]['href'] = url #a.first['href'].sub('http://www.baidu.com/link?url=','').strip
            unless url.nil?
                url = url.strip
                @ranks[id]['host'] = Addressable::URI.parse(URI.encode("http://#{url}")).host
            else
                @ranks[id]['host'] = nil
            end
        end
        #@page.search("//table[@class=\"result\"]").map{|table|@page.search("//table[@id=\"#{table['id']}\"]//span[@class=\"g\"]").first}.map{|rank|URI(URI.encode('http://'+rank.text.strip)).host unless rank.nil?}
        @ranks
    end

    def ads_bottom
        id = 0
        ads = {}
        @page.search("//table[@bgcolor='f5f5f5']").each do |table|
            next unless table['id'].nil?
            id += 1
            ads[id]= parse_ad(table)
        end
        ads
    end
    def ads_top
        id = 0
        ads = {}
        @page.search("//table[@bgcolor='f5f5f5']").each do |table|
            next if id.nil?
            id += 1
            ads[id]= parse_ad(table)
        end
        ads
    end
    def parse_ad(table)
        href = table.search("font[@color='#008000']").text.split(/\s/).first.strip
        title = table.search("a").first.text.strip
        {'title'=>title,'href' => href,'host'=>href}
    end
    def ads_right
        ads = {}
        @page.search("//div[@id='ec_im_container']").each do |table|
            table.search("div[@id]").each do |div|
                id = div['id'][-1,1].to_i+1
                title = div.search("a").first
                next if title.nil?
                title = title.text
                url = div.search("font[@color='#008000']").first
                next if url.nil?
                url = url.text
                ads[id.to_s] = {'title'=>title,'href'=>url,'host'=>url}
            end
        end
        ads
    end

    #return the top rank number from @ranks with the input host
    # def rank(host)#on base of ranks
    #     ranks.each do |id,line|
    #         id = id.to_i
    #         if host.class == Regexp
    #             return id if line['host'] =~ host
    #         elsif host.class == String
    #             return id if line['host'] == host
    #         end
    #     end
    #     return nil
    # end

    def how_many
        @how_many ||= @page.search("//span[@class='nums']").map{|num|num.content.gsub(/\D/,'').to_i unless num.nil?}.first
    end

    def related_keywords
        @related_keywords ||= @page.search("//div[@id=\"rs\"]//tr//a").map{|keyword| keyword.text}
    end

    def next
        url = @page.xpath('//a[text()="下一页>"]').first
        return if url.nil?
        url = url['href']
        url = URI.join(@baseuri,url).to_s
        body = HTTParty.get(url)
        return BaiduResult.new(body,url,@pagenumber+1)
        # @page = BaiduResult.new(Mechanize.new.click(@page.link_with(:text=>/下一页/))) unless @page.link_with(:text=>/下一页/).nil?
    end
    def has_result?
        submit = @page.search('//a[text()="提交网址"]').first
        return false if submit and submit['href'].include?'sitesubmit'
        return true
    end
end
