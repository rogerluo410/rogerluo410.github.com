---
title: 'Researching Code-loaded in engineering world'
author: roger luo
layout: post
categories:
  - Tech
tags: ruby/rails
---

我们知道， 在Ruby中，我们有三种方式加载外部文件的代码。 他们分别是： require, load, autoload。  


## Ruby中文件加载方法  

- require(name) -> true or false or raise LoadError  

> http://ruby-doc.org/core-2.1.2/Kernel.html#method-i-require   

 1. name可以是绝对路径，也可以是相对路径。Ruby会自动为name补充扩展名(.rb, .so, .etc)；   
 2. 函数执行时，如果name是绝对路径，则会去查找该文件；    
 3. 通常name是相对路径，Ruby会在$:中的目录中搜索该文件。所以通常需要$:.unshift添加搜索路径；    
 4. 找到该文件后，会运行该文件，并把该文件的绝对路径加入全局变量$"中，以此保证不重复加载；     
 5. 第一次加载返回true，已经加载返回false，找不到文件会抛出LoadError。    

 **查看全局变量列表：**  
 {% highlight ruby linenos %}
 p global_variables

 [:$;, :$-F, :$@, :$!, :$SAFE, :$~, :$&, :$`, :$', :$+, :$=, :$KCODE, 
 :$-K, :$,, :$/, :$-0, :$\, :$_, :$stdin, :$stdout, :$stderr, :$>, :$<, 
 :$., :$FILENAME, :$-i, :$*, :$?, :$$, :$:, :$-I, :$LOAD_PATH, :$", 
 :$LOADED_FEATURES, :$VERBOSE, :$-v, :$-w, :$-W, :$DEBUG, :$-d, :$0, 
 :$PROGRAM_NAME, :$-p, :$-l, :$-a, :$1, :$2, :$3, :$4, :$5, :$6, :$7, :$8, :$9]
 {% endhighlight %} 



 - load(filename, wrap=false) -> true or raise LoadError

 > http://ruby-doc.org/core-2.1.2/Kernel.html#method-i-load  

  1. filename可以是绝对路径，也可以是相对路径。Ruby不会为filename添加扩展名；   
  2. 函数执行时，如果filename是绝对路径，则会去查找该文件；   
  3. 通常filename是相对路径，Ruby会在$:中的目录中搜索该文件。所以通常需要$:.unshift添加搜索路径；   
  4. wrap为true时，被加载文件会在一个匿名模块中执行，避免污染；   
  5. load会加载文件并执行，成功会返回true，找不到文件会抛出LoadError。    


- autoload(module, filename) -> nil or raise LoadError  

> http://ruby-doc.org/core-2.1.2/Kernel.html#method-i-autoload  

  1. 将filename与module关联，当第一次使用module时，使用require加载该文件；   
  2. 执行过程与require一样；     
  3. 成功返回nil，找不到文件会抛出LoadError。        

  {% highlight ruby linenos %}
   有同目录下外部文件 modules.rb:  
   module M1
     C1 = 0
     p "In M1"
   end
 
   module M2
     C2 = 1
   end

   module M3
    C3 = 2
   end


   module M4
     autoload(:M1, "./modules.rb") #相对路径是以本文件所在目录为参照。
     p M1::C1  # 正常访问
     p M2::C2  # 正常访问
   end

  {% endhighlight %}

**三个方法的共同点：**  会搜索$:来寻找目标文件，找不到会抛出LoadError。         
**三个方法的不同点：**         
      1. require避免重复加载，无需指定扩展名；      
      2. load会重复加载，需指定扩展名；      
      3. autoload会在需要时用require加载，能避免重复加载，无需指定扩展名。    
   
   autoload采用lazy_load机制加载文件，在第一次使用时， 文件才被加载，而require 是暴力加载， 无论我们是否需要，都会加载文件。      


## require的加载机制   

按照官方解释，require将会在Ruby的$LOAD_PATH中查找对应文件并将其载入。 由于RubyGem使用地十分广泛，以至于Ruby开发团队决定予以其直接支
持，这便是为什么我们总是发觉RubyGem被载入的原因了。这也同时更好地解释了，明明也是一个Gem，为什么RubyGem没有和其他Gem放到一块儿，并遵循
Gem名加上版本号的命名方式。

在我们 require 'bar' 这样加载文件时，如果‘bar’ 这个文件在我们的工程目录中， 通常会遇到LoadError异常。  
因为很可能系统指定目录($LOAD_PATH)中并没有bar文件的路径, 导致加载异常。 一种解决方法是传入绝对路径或相对路径，但是这样并不是很好看。 

有几种方法， 可以在不用显示传入路径的情况下，解决工程中加载其他目录文件的问题。  

 (1). 引用当前rb同目录下的一个文件  
 {% highlight ruby linenos %}
 # 这也是rails中的常用方法， __FILE__指定的文件本身也代表一个层次， 相对路径是已本文件为参照。
 # 所以， 同目录下的file_to_require文件， 需要`../`退至上层， 表示`同一目录`。 
 require File.expand_path('../file_to_require', __FILE__) 

 require File.dirname(__FILE__) + '/file_to_require'

 __FILE__为常量，表示当前文件的绝对路径，如/home/oldsong/test.rb
 {% endhighlight %} 

 (2). 将目录加入全局环境变量中   
 先把目录加入LOAD_PATH变量中，然后可直接引用文件名。     
 {% highlight ruby linenos %}
  $LOAD_PATH.unshift(File.dirname(__FILE__))
  require 'bar'
 {% endhighlight %} 

 (3). 引用一个目录下所有文件 
 例如， 引用当前rb相同目录下lib/文件下所有*.rb文件。  
 {% highlight ruby linenos %}
  Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }
 {% endhighlight %} 

 或者， 使用gem [require_all][1]

## bundler 工具， 帮助我们解决包依赖问题  
 在开发中， 需要什么依赖库， 具体依赖什么版本， 只需要写一个Gemfile清单，指定下载源， 输入命令bundle   
 install后，开发环境就很方便的搭建完成， 依赖库也被安装到本机$LOAD_PATH指定的目录中。  

 虽然，bundler工具会使依赖库安装完成，但它并不保证列在Gemfile里的依赖库在运行时被载入。为了让我们的程序使用上这些库，我们需要在运行时
 调用Bundler.setup，该方法将列举在Gemfile里的所有Gem被添加到LOAD_PATH中去。

 因此，Bundler.setup的行为类似于gem方法，用于帮助我们将特定版本的Gem载入到LOAD_PATH。只不过Bundler提供了更为高级的机制，使得我们能
 够在Gemfile里集中地管理所有依赖，并且省去了一一添加依赖的繁琐过程。 


## RubyGem的gem install 和 bundler的 bundle install  
.gemspec和Gemfile分别是干嘛的？我们知道，gemspec主要是用来描述Gem的元数据信息的，我们除了可以在此包含Gem的基本信息之外，还能够在此指出本Gem具体依赖于哪些其他Gem。
不过，值得注意的是，这里仅仅是指出依赖关系，.gemspec并没有提供任何机制告诉我们，到哪里才能下载并部署这些被依赖的Gem。
 
.gemspec之所以缺少运行时的支持，那是因为下载、部署、以及载入并不是其设计之初的职责所在。这些问题是被后来者Bundler解决的。那么，既然搞清了其用途上的差异，我们又当如何
解决其内容的冗余这个问题呢？答案很简单，在Gemfile文件中调用gemspec方法，它会自动告诉Bundler到同目录下查找.gemspec文件并载入其中指明的Gem依赖。


## Rails的代码载入机制  
 Rails开发者倾向于不使用显式的代码载入机制，为了实现这个目的，Rails使用了大量的自动载入机制。其一便是autoload，关于它的原理，以后我会撰文剖析。autoload主要用于载入
 Rails自己的组件，而对于依赖Gem的载入，Rails使用了Bundler.require机制。在Rails项目的文件config/application.rb负责实现此特性：

 {% highlight ruby linenos %}
require File.expand_path('../boot', __FILE__)

require 'rails/all'

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Project_name
  class Application < Rails::Application
    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Set Time.zone default to the specified zone and make Active Record auto-convert to this zone.
    # Run "rake -D time" for a list of tasks for finding time zone names. Default is UTC.
    # config.time_zone = 'Central Time (US & Canada)'

    config.assets.enabled = false
    # The default locale is :en and all translations from config/locales/*.rb,yml are auto loaded.
    # config.i18n.load_path += Dir[Rails.root.join('my', 'locales', '*.{rb,yml}').to_s]
    # config.i18n.default_locale = :de
    config.i18n.locale = "zh-CN"
    config.autoload_paths += Dir["#{Rails.root}/lib"]
    config.assets.precompile += %w( home.css )

    config.middleware.insert_after ActionDispatch::Static, Rack::Cors do
      allow do
        origins /^http:\/\/192\.168\.0\.\d{1,3}:8888$/
        resource '*',
          # :headers => :any,
          :headers => ["Origin", "X-Requested-With", "Content-Type", "Accept", "Authorization"],
          :methods => [:get, :post, :delete, :put, :options, :head, :patch],
          :expose  => ['access-token', 'expiry', 'token-type', 'uid', 'client'],
          :max_age => 600
      end
    end

  end
end

In Gemfile:  Bundler.require(*Rails.groups) 只加载全部环境使用的和指定group里的。
gem 'state_machines-activerecord'
gem 'oneapm_rpm'
gem 'qiniu'
gem 'httparty'
gem 'acts_as_list'
gem 'connection_pool'
gem 'redis-objects'
gem 'cancancan', '~> 1.10'
gem 'rack-cors', require: 'rack/cors'
gem "settingslogic", "~> 2.0.6"

# send exception notification to mail
gem 'exception_notification'

group :doc do
  # bundle exec rake doc:rails generates the API under doc/api.
  gem 'sdoc', require: false
end

group :development do
  gem 'better_errors'
  gem 'quiet_assets'
  # gem 'rack-mini-profiler'
  gem 'brakeman', :require => false
end
# Use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.1.2'

group :test, :development do
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem 'simplecov'
  gem 'vcr'
  gem 'spork' #加上这个gem, 覆盖率才能覆盖Controller层 API接口 https://github.com/sporkrb/spork
end

group :test do
  gem 'webmock'
  gem 'rspec-sidekiq'
end
 {% endhighlight %} 


参考：  
http://www.cnblogs.com/evallife/p/3917610.html                      --Ruby中的require、load、autoload   
http://www.cnblogs.com/Dahaka/archive/2013/03/10/ruby_require.html  --require背后的故事    
http://www.jb51.net/article/69382.htm                               --举例讲解Ruby中require的使用方法   

[1]: https://rubygems.org/gems/require_all