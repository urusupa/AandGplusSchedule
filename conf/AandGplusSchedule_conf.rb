#! ruby -Ku
# encoding: utf-8

require 'rubygems'
require 'mechanize'
require 'kconv'
require 'nkf'
require 'date'
require 'common'

###############################################################################
# ---使い方---
#load "#{CONFDIR}/AandGplusSchedule_conf.rb"
###############################################################################


###############################################################################
# 定数定義
###############################################################################



begin


	@calender_init = <<-'EOS'
BEGIN:VCALENDAR
METHOD:PUBLISH
VERSION:2.0
PRODID:-//nyctea.me//Manually//JP
CALSCALE:GREGORIAN
X-WR-TIMEZONE:Asia/Tokyo
X-WR-CALNAME:文化放送 超!A&G+ タイムテーブル
	EOS
	
	@calender_init << "X-WR-CALDESC:文化放送 超!A&G+ タイムテーブル" + TargetURL + " \n"
	@calender_init << " 更新日時:" + TIMESTMP[0..3] + "/" + TIMESTMP[4..5] + "/" + TIMESTMP[6..7] + " " + TIMESTMP[8..9] + ":" + TIMESTMP[10..11] + ":" + TIMESTMP[12..13] + "\n"

	@calender_init << <<-'EOS'
BEGIN:VTIMEZONE
TZID:Japan
BEGIN:STANDARD
DTSTART:19390101T000000
TZOFFSETFROM:+0900
TZOFFSETTO:+0900
TZNAME:JST
END:STANDARD
END:VTIMEZONE
	EOS

rescue => ex
p ex
end



