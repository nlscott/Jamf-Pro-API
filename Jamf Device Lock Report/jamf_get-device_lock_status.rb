#!/usr/bin/ruby

require "uri"
require "json"
require "time"
require "net/http"
require 'openssl'


## VARIABLES -------------------------------------------------------------------
$jamfpro_url = "https://company.jamfcloud.com" 
$api_pw = "Your API KEY HERE"


## METHODS -------------------------------------------------------------------
def getToken
    url = URI("#{$jamfpro_url}/api//v1/auth/token")
    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true
    request = Net::HTTP::Post.new(url)
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Basic #{$api_pw}"
    response = https.request(request)
    results = JSON.parse(response.read_body)
    $bearerToken=results['token']
    $tokenExpiration=results['expires']
    $tokenExpirationEpoch=Time.parse($tokenExpiration).to_i
    # puts "Token granted"
end

def checkTokenExpiration
    current_time= Time.now.to_i
    # puts "Checking if Token is valid"
    if $tokenExpirationEpoch >= current_time
        # puts "Epoch time is #{$tokenExpirationEpoch}" 
        time_difference = $tokenExpirationEpoch - current_time
        time_till_token_expire = Time.at(time_difference).utc.strftime("%H:%M:%S")
        # puts "Token is valid"
        # puts "Token expires in: " + time_till_token_expire
    else
        # puts "Token is invalid"
    end
end


def invalidateToken
    url = URI("#{$jamfpro_url}/api/v1/auth/invalidate-token")
    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true
    request = Net::HTTP::Post.new(url)
    request["Authorization"] = "Bearer #{$bearerToken}"
    response = https.request(request)
    status = response.code
    if status == "204"
        # puts "Token successfully invalidated"
    elsif status == "401"
        # puts "Token already invalid"
    else
        # puts "error: something went wrong"
    end
end

def mapComputerIDHash
    $mapIDtoComputerName = Hash.new
    url = URI("#{$jamfpro_url}/JSSResource/computers")
    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true
    request = Net::HTTP::Get.new(url)
    request["Accept"] = 'application/json'
    request["Authorization"] = "Bearer #{$bearerToken}"
    response = https.request(request)
    results = JSON.parse(response.read_body)
    results["computers"].each do |item|
        $mapIDtoComputerName["#{item["id"]}"] = "#{item["name"]}"
    end
end

                                
def getDeviceLockStatus
    $deviceLockStatusArray = Array.new
    url = URI("#{$jamfpro_url}/JSSResource/computercommands/name/DeviceLock")
    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true
    request = Net::HTTP::Get.new(url)
    request["Accept"] = "application/json"
    request["Content-Type"] = "application/json"
    request["Authorization"] = "Bearer #{$bearerToken}"
    response = https.request(request)
    results = JSON.parse(response.read_body)
    results["computer_commands"]["computer_command"].each do |item|
        commandSent = item["date_sent"]
        if item["apns_result_status"].empty?
            commandStatus = "Pending"
        else
            commandStatus = item["apns_result_status"]
        end
        computerID = item["computers"]["computer"]["id"]
        computerSerial = item["computers"]["computer"]["serial_number"]
        computerID  = {"ID" => "#{computerID}", "Serial" => "#{computerSerial}", "sent" => "#{commandSent}", "status" => "#{commandStatus}"}
        $deviceLockStatusArray << computerID
    end
end


def getDeviceLockHash
    $resultsArray = Array.new
   $deviceLockStatusArray.each do |item|
        computerID = item["ID"]
        computerSerial = item["Serial"]
        commandSent = item["sent"]
        commandStatus = item["status"]
        computerName = $mapIDtoComputerName["#{item["ID"]}"]
        computerID  = {"id" => "#{computerID}".to_i, "name" => "#{computerName}", "serial" => "#{computerSerial}", "sent" => "#{commandSent}", "status" => "#{commandStatus}"}
        $resultsArray << computerID
   end
end


def printDeviceLockReport
    puts "Total Devices Locked: #{$resultsArray.size}"
    puts "#-----------------------------"
    puts ""

    $resultsArray = $resultsArray.sort_by! { |k| k["id"]}
    $resultsArray.each do |item|
        puts "Computer ID: #{item["id"]}"
        puts "Computer Name: #{item["name"]}"
        puts "Computer Serial: #{item["serial"]}"
        puts "Date Sent: #{item["sent"]}"
        puts "Command Status: #{item["status"]}"
        puts ""
    end
end




## Updates Static groups with Comptuer ID
def updateNumberOfLockedComputersGroup
    url = URI("#{$jamfpro_url}/JSSResource/computergroups/id/395")
    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true
    request = Net::HTTP::Put.new(url)
    request["Accept"] = "application/xml"
    request["Content-Type"] = "application/xml"
    request["Authorization"] = "Bearer #{$bearerToken}"
    request.body = "<computer_group><computer_additions><computer><id>8</id></computer></computer_additions></computer_group>"
    response = https.request(request)
    puts response.read_body
end


## COMMANDS -------------------------------------------------------------------
getToken
checkTokenExpiration
mapComputerIDHash
getDeviceLockStatus
getDeviceLockHash
printDeviceLockReport
invalidateToken
