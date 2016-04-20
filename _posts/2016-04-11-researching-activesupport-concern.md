---
title: 'Researching ActiveSupport::Concern'
author: roger luo
layout: post
categories:
  - Tech
tags: rails
---

在设计程序框架时，我们可能会定义很多类和模块。 并且这些类和模块之间有着很复杂的网状依赖关系。 

通常， 我们这么定义一些依赖： 

- 手动式模块横向依赖管理
{% highlight ruby linenos %}
module Ma
 def self.included(base)
   base.send(:do_host_something) 
 end
end

module Mb
  def self.included(base)
   base.send(:do_host_something) 
  end
end

class CHost
 include Ma, Mb
end
{% endhighlight %}

类CHost依赖2个模块Ma, Mb。 那么， 问题来了， 当需要依赖1个模块， 20个模块， 100个模块时... 我们是否也需要一个一个的加入？ 
像 include Ma, Mb, Mc, ... Mx。 显然这是模块依赖管理的一个小麻烦。 我把它叫做手动式模块横向依赖管理。

好了， 通常我们会想到另一种方法， 将modules的依赖写在module中， 用一个module管理这些依赖， 那么在类中只需要引用一个依赖的模块。 
从结构上看这是一种纵向依赖结构。  

- 模块纵向依赖结构  
{% highlight ruby linenos %}
module Ma
  include Mb, Mc, Md 

  def self.included(base)
    base.send(:do_host_something)
  end
end

class CHost
  include Ma  #仅仅需要include Ma即可。
end
{% endhighlight %} 

这种结构看似没什么问题， 其实也没什么问题。 但是， 在有一种场景下， 它将使我们陷入尴尬境地。 

类是一种抽象， 一个类描述一类特定的对象。 但是， 有时我们希望类能够拥有一些特别的功能或者特性化。 多态是一种方式， 但是会使类继承结构复杂化。 

另一种方式， 是使用模块， 在模块中打开类，使用反射机制， 以使类能特性化。  

模块纵向依赖结构中， 一个最大的问题是，由于`Mb,Mc,Md`变成被`Ma`所include, 在`Ma`的函数`self.included(base)`中， `base`变成了`Mb,Mc,Md` 三个模块， 导致`Ma`中无法对宿主类`CHost`进行扩展。 

- 模块横向依赖结构  
终于回到主题了。 我们需要一种方法， 使我们能够在多依赖模块的场景中，宿主类只需include一个模块就可以在其他所有依赖的模块中， 扩展自己。 

`ActiveSupport::Concern` 就是为这种场景而生。 

 {% highlight ruby linenos %}
 module Ma
   extend ActiveSupport::Concern
   included do
     self.send(:do_host_something)
   end
 end

 module Mb
   extend ActiveSupport::Concern
   include Ma
   included do
     self.send(:do_host_something)
   end
 end

 class CHost
   include Mb  #只需include Mb, 而不需要知道Mb依赖了哪些模块。  
 end
 {% endhighlight %} 

 通过[源码][1]， 我们可以看到：  
 {% highlight ruby linenos %}
   def append_features(base)
      if base.instance_variable_defined?(:@_dependencies)
        base.instance_variable_get(:@_dependencies) << self
        return false
      else
        return false if base < self
        @_dependencies.each { |dep| base.include(dep) }
        super
        base.extend const_get(:ClassMethods) if const_defined?(:ClassMethods)
        base.class_eval(&@_included_block) if instance_variable_defined?(:@_included_block)
      end
    end

    def included(base = nil, &block)
      if base.nil?
        raise MultipleIncludedBlocks if instance_variable_defined?(:@_included_block)

        @_included_block = block
      else
        super
      end
    end
 {% endhighlight %} 

我们可以看到， `ActiveSupport::Concern` 的`included`函数中， 如果有代码块对象， 则使用class_eval进行扩展。  

另外, 如果我们定义`module ClassMethods` 和 `module InstanceMethods`， 它会自动帮我们将实例方法和类方法载入到宿主里去。  
就不用写 `send(:include, InstanceMethods)` 和 `send(:extend, ClassMethods)`。  

 {% highlight ruby linenos %}
   module Foo
    extend ActiveSupport::Concern
    included do
        self.send(:do_host_something)
    end

     module ClassMethods
        def bite
          # do something
        end
     end

     module InstanceMethods
        def poke
           # do something
        end
     end
   end
 {% endhighlight %} 


另一个例子:  
 {% highlight ruby linenos %}
  module OuterFile
    extend ActiveSupport::Concern

    included do
      validates :file_id, presence: true

      def file
        Photo.new(self.file_id)
      end
      
    end
  end
 {% endhighlight %} 

 最后，题外话， Concern最好命名以able结尾!

 参考：     
 https://ruby-china.org/topics/19812  --ActiveSupport::Concern 小结   

 [1]: https://github.com/rails/rails/blob/master/activesupport/lib/active_support/concern.rb
