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