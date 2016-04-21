---
title: 'Researching code load in engineering world'
author: roger luo
layout: post
categories:
  - Tech
tags: ruby/rails
---

我们知道， 在Ruby中，我们有三种方式加载外部文件的代码。 他们分别是： require, load, autoload。  


## Ruby中的文件加载方法  

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

 [:$;, :$-F, :$@, :$!, :$SAFE, :$~, :$&, :$`, :$', :$+, :$=, :$KCODE, :$-K, :$,, :$/, :$-0, :$\, :$_, :$stdin, :$stdout, :$stderr, :$>, :$<, :$., :$FILENAME, :$-i, :$*, :$?, :$$, :$:, :$-I, :$LOAD_PATH, :$", :$LOADED_FEATURES, :$VERBOSE, :$-v, :$-w, :$-W, :$DEBUG, :$-d, :$0, :$PROGRAM_NAME, :$-p, :$-l, :$-a, :$1, :$2, :$3, :$4, :$5, :$6, :$7, :$8, :$9]
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
   module M4
     autoload(:M1, "./modules.rb")
     p M1::C1  # 正常访问
     p M2::C2  # 正常访问
   end

  {% endhighlight %}

三个方法的共同点： 会搜索$:来寻找目标文件，找不到会抛出LoadError。   
不同点： 
   1. require避免重复加载，无需指定扩展名；    
   2. load会重复加载，需指定扩展名；   
   3. autoload会在需要时用require加载，能避免重复加载，无需指定扩展名。  autoload采用lazy_load机制加载文件，在第一次使用时， 文件才被加载，而require 是暴力加载， 无论我们是否需要，都会加载文件。  


## require的加载机制   

按照官方解释，require将会在Ruby的$LOAD_PATH中查找对应文件并将其载入。 由于RubyGem使用地十分广泛，以至于Ruby开发团队决定予以其直接支
持，这便是为什么我们总是发觉RubyGem被载入的原因了。这也同时更好地解释了，明明也是一个Gem，为什么RubyGem没有和其他Gem放到一块儿，并遵循
Gem名加上版本号的命名方式。

在我们 require 'bar' 这样加载文件时，如果‘bar’ 这个文件在我们的工程目录中， 通常会遇到LoadError异常。  
因为很可能系统指定目录($LOAD_PATH)中并没有bar文件的路径, 导致加载异常。 一种解决方法是传入绝对路径或相对路径，但是这样并不是很好看。 

有几种方法， 可以在不用显示传入路径的情况下，解决工程中加载其他目录文件的问题。  

 1. 引用当前rb同目录下的一个文件  
 {% highlight ruby linenos %}
 require File.expand_path('../file_to_require', __FILE__) # 这也是rails中的常用方法
 require File.dirname(__FILE__) + '/file_to_require'

 __FILE__为常量，表示当前文件的绝对路径，如/home/oldsong/test.rb
 {% endhighlight %} 

 2. 将目录加入全局环境变量中   
 先把目录加入LOAD_PATH变量中，然后可直接引用文件名。     
 {% highlight ruby linenos %}
  $LOAD_PATH.unshift(File.dirname(__FILE__))
  require 'bar'
 {% endhighlight %} 

 3. 引用一个目录下所有文件 
 例如， 引用当前rb相同目录下lib/文件下所有*.rb文件。  
 {% highlight ruby linenos %}
  Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }
 {% endhighlight %} 

 或者， 使用gem [require_all][1]



参考：  
http://www.cnblogs.com/evallife/p/3917610.html                      --Ruby中的require、load、autoload   
http://www.cnblogs.com/Dahaka/archive/2013/03/10/ruby_require.html  --require背后的故事    
http://www.jb51.net/article/69382.htm                               -举例讲解Ruby中require的使用方法   

[1]: https://rubygems.org/gems/require_all