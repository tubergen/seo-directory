class ApplicationPresenter
  def h
    self.class.h
  end

  class << self
    def h
      Draper::Decorator.h
    end
  end
end