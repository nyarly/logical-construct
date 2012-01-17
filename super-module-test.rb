module M
  def demo
    super
    p :module => M
  end
end

module N
  def demo
    super
    p :module => N
  end
end

module O
  def demo
    super
    p :module => O
  end
end

module P
  def demo
    super
    p :module => P
  end
end

module Q
  def demo
    super
    p :module => Q
  end
end

class A
  def demo
    p :class => A
  end
end

class B < A
  include M
  include N
  def and_o
    extend O
  end

  def and_p
    class << self
      include P
    end
  end

  def and_q
    B.class_eval{include Q}
  end

  if defined? first_time
    def demo
      super
      p :class => B
    end
  end
end

b = B.new
b.and_o
b.and_p
b.and_q

def b.demo
  super
  p :singleton => :b
end

class B
  def demo
    super
    p :reopen => B
  end
end

b.demo
