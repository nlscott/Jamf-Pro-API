#!/usr/bin/ruby

require "uri"
require "json"
require "time"
require "net/http"
require "openssl"
require "fileutils"


## UPDATE THESE VARIABLES ------------------------------------------------------
$jamfpro_url = "https://company.jamfcloud.com" 
$api_pw = "Your API KEY HERE"


## METHODS ---------------------------------------------------------------------

def getToken
    #request New token
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

    ### SANITY CHECK
    # puts "Token granted"
end

def checkTokenExpiration
    #check if token is valid

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
    #revoke token
    url = URI("#{$jamfpro_url}/api/v1/auth/invalidate-token")
    https = Net::HTTP.new(url.host, url.port)
    https.use_ssl = true
    request = Net::HTTP::Post.new(url)
    request["Authorization"] = "Bearer #{$bearerToken}"
    response = https.request(request)
    status = response.code

    ### SANITY CHECK
    # if status == "204"
    #     puts "Token successfully invalidated"
    # elsif status == "401"
    #     puts "Token already invalid"
    # else
    #     puts "error: something went wrong"
    # end
end



def getAllApplicationInventory
    #this is the main function
    #loops through all computers inventory and only looks at Applications section
    $applicationHash = Hash.new(0)

    url = URI("#{$jamfpro_url}/api/v1/computers-inventory?section=APPLICATIONS&page=0&page-size=2000&sort=id%3Aasc")
    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
    request = Net::HTTP::Get.new(url)
    request["accept"] = 'application/json'
    request["Authorization"] = "Bearer #{$bearerToken}"
    response = http.request(request)
    results = JSON.parse(response.read_body)
    
    results["results"].each do |item|
        item["applications"].each do |item|
            $applicationName = item["name"]
            $applicationHash["#{$applicationName}"] +=1
        end
    end
end


def listAllInstalledApps
    # Prints back report sorty by most installed apps to least
    $applicationHash.sort_by {|_key, value| value}.reverse.each do |k,v|
        puts " #{k} = #{v}"
    end
end


def totalNumberOfOneInstalledApps
    #prints the total number of apps that have been installed once
    @oneOffApps = Hash.new
    $applicationHash.each do |name, count|
        if count == 1
            @oneOffApps["#{name}"] = "#{count}"
        end
    end
 
    puts @oneOffApps.count
end


def listofOneInstallApps
    #prints list of all apps by name that have been installed once
    @oneInstalledApps = Hash.new
    $applicationHash.each do |name, count|
        if count == 1
            @oneInstalledApps["#{name}"] = "#{count}"
        end
    end

    puts @oneInstalledApps.keys
end


def webBrowserReport
    #reports back on how many installs of these browsers there are
    $webBroswerArray = [
        "Google Chrome.app",
        "Google Chrome Canary.app",
        "Firefox.app",
        "Firefox Developer Edition.app",
        "Safari.app",
        "Safari Technology Preview.app",
        "Microsoft Edge.app", 
        "Brave Browser.app", 
        "Arc.app",
        "Opera.app",
        "LinCastor Browser.app",
        "LockDown Browser.app", 
        "Tor Browser.app",
        "Vivaldi.app",
        "DuckDuckGo.app"
    ]

    $applicationHash.sort_by {|_key, value| value}.reverse.each do |k,v|
        if $webBroswerArray.include?("#{k}")
            puts "#{k} = #{v}"
        end
    end
end





## COMMANDS --------------------------------------------------------------------
## These should stay uncommented. Gets a bearer token, checks to make sure it's
## valid, and then `getAllApplicationInventory` is the main function that querys
## jamf pro and creats an application hash with app name and number of installs
getToken
checkTokenExpiration
getAllApplicationInventory


### REPORTS --------------------------------------------------------------------
## uncomment the report you want to run

listAllInstalledApps
# webBrowserReport
# totalNumberOfOneInstalledApps
# listofOneInstallApps


## after reporting, revoke current token. This should stay uncommented to make 
## sure after each call the current bearer token is revoked and can't be reused
invalidateToken
