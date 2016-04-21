---
title: 'Researching Module include/extend plus'
author: roger luo
layout: post
categories:
  - Tech
tags: rails
---


##为什么要定义一个module， 以供其他Class 或 Module 去include 或 extend 实现功能扩展？  

我们看看下面的一个场景：  

- Scene one  
 {% highlight ruby linenos %}
 module M1
   def self.m1_module_func
     p "In module"
   end
 end

 class C1
   def self.c1_class_method1
     M1::m1_module_func  # 访问M1的方法 m1_module_func
   end

   class << self
     M1::m1_module_func # 访问M1的方法 m1_module_func
   end
 end
 {% endhighlight %} 

既然，我们可以通过模块域名访问的方式访问模块的方法，那么， 为什么还要通过include, extend去扩展使类或模块变得更大更臃肿呢？   

其实不然，延伸来看，一些公共的模块抽象出来， 还是可以达到代码复用的作用。 如果用`ActiveSupport::Concern` 可以处理复杂的嵌套扩展中的Base问题。  从model层设计的角度看， `代码过多加 module, 职责过多加 scope`。  


##有关include、extend和对象的祖先链、隐藏类之间的关系  

- Scene two  
{% highlight ruby linenos %}
module M2
  # M2的实例方法
  def m2_instance_method
    p "In m2_instance_method"
  end

  # M2的类方法
  def self.m2_module_method
    p "In M2::m2_module_method"
  end
end

class C2
  include M2

  p self.ancestors
  p self.instance_methods
  p self.singleton_methods
end

class C3
  extend M2

  p self.ancestors
  p self.instance_methods
  p self.singleton_methods
end
{% endhighlight %}

Output:  
{% highlight ruby linenos %}
In C2:  
[C2, M2, Object, Kernel, BasicObject]   
[:m2_instance_method, :nil?, :===, :=~, :!~, :eql?, :hash, :<=>, :class, 
:singleton_class, :clone, :dup, :taint, :tainted?, :untaint, :untrust, 
:untrusted?, :trust, :freeze, :frozen?, :to_s, :inspect, :methods, 
:singleton_methods, :protected_methods, :private_methods, :public_methods,
:instance_variables, :instance_variable_get, :instance_variable_set, 
:instance_variable_defined?, :remove_instance_variable, :instance_of?, 
:kind_of?, :is_a?, :tap, :send, :public_send, :respond_to?, :extend, 
:display, :method, :public_method, :singleton_method, :define_singleton_method, 
:object_id, :to_enum, :enum_for, :==, :equal?, :!, :!=, :instance_eval, 
:instance_exec, :__send__, :__id__]  
[]   

In C3:  
[C3, Object, Kernel, BasicObject]
[:nil?, :===, :=~, :!~, :eql?, :hash, :<=>, :class, :singleton_class, 
:clone, :dup, :taint, :tainted?, :untaint, :untrust, :untrusted?, 
:trust, :freeze, :frozen?, :to_s, :inspect, :methods, :singleton_methods, 
:protected_methods,:private_methods, :public_methods, :instance_variables, 
:instance_variable_get, :instance_variable_set, :instance_variable_defined?, 
:remove_instance_variable, :instance_of?, :kind_of?, :is_a?, :tap, :send, 
:public_send, :respond_to?, :extend, :display, :method, :public_method, 
:singleton_method, :define_singleton_method, :object_id, :to_enum, :enum_for, 
:==, :equal?, :!, :!=, :instance_eval, :instance_exec, :__send__, :__id__]
[:m2_instance_method]
{% endhighlight %}

通过以上输出， 我们可以得出结论：  
  1. module的实例方法才能被扩展， 类方法始终只属于自己。   
  2. 使用include扩展， module进入该类的祖先链中， 仅公有和保护类型的实例方法可以变成该类的实例方法。   
  3. 使用extend扩展， module不会进入该类的祖先链中， 仅公有和保护类型的实例方法可以变成该类的类方法，即进入类的隐藏类中。     


##在多重扩展中， 有同名方法时， 会调用哪个module/class的？  
- Scene three
{% highlight ruby linenos %}
module M2
  # M2的实例方法
  def m2_instance_method
    p "In m2_instance_method"
  end

  # M2的类方法
  def self.m2_module_method
    p "In M2::m2_module_method"
  end
end

class C2
  include M2

  p self.ancestors
  p self.instance_methods
  p self.singleton_methods
end

class C3
  extend M2

  p self.ancestors
  p self.instance_methods
  p self.singleton_methods
end

module M3
  def m2_instance_method
    p "In m2_instance_method of M2"
  end
end

class C4 < C2
  include M2, M3
  
  p self.ancestors #=> [C4, M3, C2, M2, Object, Kernel, BasicObject]
  p self.instance_methods
end

class C5 < C3
  include M3, M2
  
  p self.ancestors #=> [C5, M3, M2, C3, Object, Kernel, BasicObject]
  p self.instance_methods
end
{% endhighlight %}

通过以上输出， 我们可以得出结论：       
 1. 在C4中， 由于父类C2也扩展了M2， 所以M2在祖先链考前的位置， 根据就近原则， C4的实例访问的是M3的实例方法。        
 2. 在C5中， 我们可以看出模块间的依赖关系，就近原则， 先include的先使用。    
 

##在使用class << self时遇到的问题  

 通常我们认为， 在类中， `def self.method end;` 和 用`class << self` 打开类隐藏类， 去定义类的方法， 这两种方式没有区别。 
 虽然， 这两种方式都存放在类的隐藏类中， 但是， 还是会有些小的不同。  

 - Scene four  
 {% highlight ruby linenos %}
  module M1
    CT = "ok"
  end

  class C0
    CC = "Not ok"
  end

  class C1 < C0
    CK = "ck"
    include M1

    def self.method1
      puts self
      puts "#{CK} in method1" #=> "ck in method1"
      puts "#{CC} in method1" #=> "Not ok in method1"
      puts "#{CT} in method1" #=> "ok in method1"
    end

    class << self    
      def method2
        puts self
        puts self.const_defined?(:CT) #=> true
        puts self::CT  #=> ok
        puts "#{CK} in method2" #=> "ck in method2"
        puts "#{CC} in method2" #=> NameError: uninitialized constant Class::CC
        puts "#{CT} in method2" #=> NameError: uninitialized constant Class::CT 
      end
    end
  end

  C1.method1
  C1.method2 
 {% endhighlight %}

 Output:  
 {% highlight ruby linenos %}
    C1
    ck in method1
    ok in method1
    C1
    true
    ok
    ck in method2
    NameError: uninitialized constant Class::CT in `method2'
 {% endhighlight %}
可以看到， 在隐藏类中， 无法直接访问CT, 但是却可以C1::CT（实际是通过M1::CT找到该常量）、M1::CT 指明访问路径的访问CT。 这是为什么呢？  

整个依赖结构是不是这样的： 
{% highlight ruby linenos %} 
    BasicObject  
        |  
      Kernel  
        |  
      Object  
        |   
        M1   
        |  
        C1 —— C1 EigenClass(隐藏类)  
{% endhighlight %}         

我们可以得出结论：          
 1. 类方法都存放于隐藏类中， 但是它却和祖先链无关， 导致在隐藏类中无法访问祖先链上的元素(不认识这个常量)， 需要指明访问路径。    
 2. 无论是继承还是模块扩展， 常量是不会继承下去的（在类中其实是去祖先链上查找，所以可以不用带上访问路径）， 由于， 隐藏类不在祖先链上，所以在隐藏类中必须加上访问路径，去该类的祖先链上查找。     


##类的隐藏类是否也继承？  
- Scene five    
{% highlight ruby linenos %}
  class C0
    def self.method0
      p "In method0"
    end
  end

  class C1 < C0
    def self.method1
      p "In method1"
    end

    p self.singleton_methods  #=> [method1, method0]
  end
{% endhighlight %}
说明类的隐藏类中方法也被继承！
依赖模型如下: 
{% highlight ruby linenos %} 
     C0 - C0 EigenClass  
     |         |  
     C1 - C1 EigenClass 
{% endhighlight %}        

参考：    
https://ruby-china.org/topics/7709  --“胖” Model 用 ActiveSupport::Concern 瘦身    
https://signalvnoise.com/posts/3372-put-chubby-models-on-a-diet-with-concerns    
https://ruby-china.org/topics/10654  --在 module 定义时，使用 class << self 的目的是什么呢？  
https://ruby-china.org/topics/4777  --Ruby 的常量查找路径问题      
