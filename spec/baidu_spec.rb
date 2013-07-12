# encoding: utf-8

#coding:UTF-8
require './lib/baidu.rb'
describe Baidu do
    baidu = Baidu.new(10)
    page = baidu.query '百度'

    it "should return BaiduResult" do
        page.class.should == BaiduResult
    end

    it "should return 100,000,000" do
        page.how_many.should > 100000
    end
    it "should return 1" do
        page.rank('www.baidu.com').should == 1
    end

    it "should return BaiduResult" do
        page.next.class.should == BaiduResult
    end

    it "should return true" do
        bool = baidu.popular?'百度'
        bool.should == true
    end

    it "should return false" do
        bool = baidu.popular?'lavataliuming'
        bool.should == false
    end

    it "should return over 5 words beginning with the query_word" do
        query_word = '为'
        suggestions = baidu.suggestions(query_word)
        suggestions.size.should > 5
        suggestions.each do |suggestion|
            suggestion[0].should == query_word
        end
    end

    it "should return 100,000,000" do
        baidu.how_many_pages('baidu.com').should == 100000000
    end

    it "should return 100,000,000" do
        baidu.how_many_links('baidu.com').should == 100000000
    end
    it "should return 100,000,000" do
        baidu.how_many_pages_with('baidu.com','baidu.com').should. == 100000000
    end
    it "查询已经被收录的页面收录情况时,应返回true" do
        baidu.indexed?('http://www.baidu.com').should == true
    end
    it "查询一个不存在的页面收录情况时,应返回true" do
        baidu.indexed?('http://zxv.not-exists.com').should == false
    end
    page1 = baidu.query('seoaqua.com')
    it "查询结果应该都能拿到title,href,host" do
        page1.ranks.each do |id,rank|
            rank['href'].should_not == nil
            rank['text'].should_not == nil
            rank['host'].should_not == nil
        end
    end
    # ads_page = baidu.query '减肥药'

end
