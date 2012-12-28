require 'rubygems'
require 'pp'
require 'mechanize'
require 'nokogiri'
require 'logger'
require 'readline'
require 'aes_crypter'

$downloadlDir = 'downloads/'
$baseUrl = 'http://www.spoluziaci.sk/'
$mechanizeLog = 'mechanize.log'
$passwd = '.key'
$class_year = '2014'
$class_field = 'AI'
$account_page_class_list_regexp = /moj[ae] tried[ay]/

module MyLogger
  def log(msg)
    puts msg
  end
end

class DocumentLinkExtractor
  include MyLogger
  def initialize
  end

  def extract_files(html)
    doc = Nokogiri::HTML(html, nil, 'UTF-8')
    doc.encoding = 'utf-8'
    doc.xpath('//div[@class="dokument"]//table//tr').
    map { |cell| cell.at('td') }.
    select { |td| td != nil && td.at('a') != nil }.
    collect do |td|
      a = td.at('a')
      if a != nil
        name = a.text.strip
        href = a.attr('href')
        { :name => name,
          :href => href
        }
      end
    end
  end

  def extract_folders(html)
    Nokogiri::HTML(html).xpath('//table[@class="slozky"]//td/div/a').
    collect do |cell|
      name = cell.text.strip
      href = cell.attr('href')
      { :name => name,
        :href => href
      }
    end
  end
end

class SpoluziaciCrawler
  include MyLogger
  include AESCrypter
  def initialize(download_dir)
    @agent = Mechanize.new
    @agent.user_agent_alias = 'Linux Firefox'
    @agent.follow_meta_refresh = true
    @agent.redirect_ok = true
    @agent.log = Logger.new $mechanizeLog
    @extractor = DocumentLinkExtractor.new
    @download_dir = download_dir
  end

  def crawl
    account = doLogin
    doSaveCookies "cookies.jar"

    classlist = goClassList(account)
    myclass = goClass(classlist)
    docroot = goDocRoot(myclass)
    docroot_html = docroot.body

    folders = lookupFolders(docroot_html)
    files = processFoldersIntoFiles(folders)

    processFiles(files)
  end

  def doLogin
    homepage = goHomepage
    log "Submitting Login info"
    page_acc = homepage.form_with(:action => /login/) do |login_form|
      login_form.email = getDecrypt[:login]
      login_form.password = getDecrypt[:pass]
    end.
    submit
  end

  def goHomepage
    log "Requesting Homepage"
    @agent.get($baseUrl)
  end

  def goClassList(page_acc)
    log "Requesting List of classes"
    link = page_acc.link_with(:text => $account_page_class_list_regexp)
    if link != nil
      classlist_page = link.click
    else
      log "Can't find link to class list, probably not logged in."
      log "Try deleting #{$passwd} file."
      log "Exiting!"
      exit 1
    end
  end

  def goClass(classlist_page)
    goClassRegExp(classlist_page, /#{$class_year}.*#{$class_field}/)
  end

  def goClassRegExp(classlist_page, regexp)
    log "Requesting class matching regexp #{regexp}"
    class_page = classlist_page.link_with(:text => regexp).click
  end

  def goDocRoot(class_page)
    log "Requesting List of folders"
    docroot_page = class_page.link_with(:text => /^Dokumenty/).click
  end

  def lookupFolders(html)
    folders = @extractor.extract_folders(html)
  end

  def processFoldersIntoFiles(folders)
    folders.collect do |folder|
      files = goFiles(folder)
      files_html = files.body
      lookupFiles(files_html).collect do |file|
        entry = { :folder => folder,
          :name => file[:name],
          :href => file[:href]
        }
      end
    end.flatten
  end

  def goFiles(folder)
    log "Requesting Files in folder #{folder[:name]}"
    folder_page = @agent.get(folder[:href])
  end

  def lookupFiles(html)
    files = @extractor.extract_files(html)
  end

  def processFiles(files)
    i = 0
    files.each do |file|
      i += 1
      filename = "#{@download_dir}#{file[:folder][:name]}-#{file[:name]}"
      log "Processing file #{filename}"

      if !File.exists?(filename)
        log "Downloading to #{filename}"
        log "\t... from #{file[:href]}"
        contents = @agent.get_file(file[:href])
        write(filename, contents)
      else
        log "Skipping #{filename}"
        log "\t... file exists"
      end
    end
  end

  def doSaveCookies(filename)
    log "Saving cookies to #{filename}"
    @agent.cookie_jar.save_as(filename)
  end

  def crypt_key
    "WLDNSDvjRBresv4;c6\45869W$#w5tv3[="
  end

  def getDecrypt
    if @decrypt == nil
      if !File.exists?($passwd)
        @decrypt = askForLogin
        encrypt_to("#{@decrypt[:login]}\n#{@decrypt[:pass]}", $passwd)
      else
        d = decrypt_from($passwd).split("\n")
        if d.length == 2
          @decrypt = { :login => d[0], :pass => d[1] }
        else
          @decrypt = askForLogin
          encrypt_to("#{@decrypt[:login]}\n#{@decrypt[:pass]}", $passwd)
        end
      end
    end
    puts "Using login info: #{@decrypt.to_s}"
    @decrypt
  end

  def askForLogin
    puts "Login into for #{$baseUrl}"
    l = Readline.readline("Login: ", true)
    p = Readline.readline("Password: ", false)
    { :login => l, :pass => p }
  end
end

def write(file, contents)
  File.open(file, 'w') do |f|
    f.write(contents)
  end
end

puts "Crawling web"
SpoluziaciCrawler.new($downloadlDir).crawl
