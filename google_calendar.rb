#
# Copyright (C) 2009 by maiha <maiha@wota.jp>
#
# USAGE: <%= google_calendar 'MAIL', 'PASS', 'CALENDAR_FEED_URL', 'OPTIONS' %>
#
# OPTIONS:
#   :max  : max number of output (default: 10)
#   :days : range of output days (default: 3..14)
#           (min: ensure at least count of entries even if count exceeds :max option)
#           (max: muximum days for search)
#
# EXAMPLE:
#   <ul class=calendar>
#     <%= goolge_calendar 'maiha@gmail...', 'xxx', 'http://www.google.com/calendar/feeds/t69rg.../full', :days=>(1..7), :limit=>20 %>
#   </ul>

require 'rubygems'
require 'gcalapi'

class GoogleCalendar::Event
  def pretty_date
    wday = %w( 日 月 火 水 木 金 土 )[st.wday] 
    st.strftime("%Y/%m/%d(#{wday})")
  rescue
    ''
  end

  def link?
    %r{^https?://} === where.to_s.strip
  end
 
  def url
    if link?
      where.to_s.strip.split.first
    else
      nil
    end
  end

  def summary
    str = ''
    if st
      str << st.strftime(" %H:%M") if !(st.hour==0 && st.min==0 && st.sec==0)
    end
    str << " %s" % title
    if link?
      str = "<a href='%s'>%s</a>" % [url, str]
    else
      str << " (%s)" % where unless where.to_s.empty?
    end
    str.strip
  end
end

class GoogleCalendar::Calendar
  def self.entries_from_xml(xml)
      REXML::Document.new(xml).root.elements.each("entry"){}.map do |elem|
        elem.attributes["xmlns:gCal"] = "http://schemas.google.com/gCal/2005"
        elem.attributes["xmlns:gd"] = "http://schemas.google.com/g/2005"
        elem.attributes["xmlns"] = "http://www.w3.org/2005/Atom"
        entry = GoogleCalendar::Event.new
        entry.srv = @srv
        entry.load_xml("<?xml version='1.0' encoding='UTF-8'?>#{elem.to_s}")
      end
  end

  def self.top(events, options = {})
    limit  = options[:max] || 10
    accept = Time.now + (options[:days].min || 3) * 86400
    lists = []

    events.each do |event|
      event.st = event.st.localtime if event.st
      event.en = event.en.localtime if event.en
    end
    events.sort!{|a,b| a.st <=> b.st}

    events.each do |event|
      if event.st <= accept
        lists << event
      elsif lists.size < limit
        lists << event
      else
        break
      end
    end
    return lists
  end
end

def google_calendar(mail, pass, url, options = {})
  options[:days] ||= (3..14)
  options[:days] = (options[:days].to_i..options[:days].to_i) unless options[:days].is_a?(Range)
  srv = GoogleCalendar::Service.new(mail, pass)
  cal = GoogleCalendar::Calendar.new(srv, url)
  events = cal.events(:orderby=>"starttime", :"start-min"=>Time.now, :"start-max"=>(Time.now+options[:days].max*86400
))

  grouped = {}
  GoogleCalendar::Calendar.top(events, options).each do |e|
    (grouped[e.pretty_date] ||= []) << e.summary
  end
  grouped.keys.each do |day|
    grouped[day] = grouped[day].map{|i| "<li>%s</li>" % i}.join
  end
  schedule = grouped.keys.sort.map{|day| "<li>#{day}<ul>#{grouped[day]}</ul></li>"}
  return schedule
end

