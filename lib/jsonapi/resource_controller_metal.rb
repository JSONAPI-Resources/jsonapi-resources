module JSONAPI
  class ResourceControllerMetal < ActionController::Metal
    FORCE_SSL_MODULE = if Gem::Requirement.new('< 6.1').satisfied_by?(ActionPack.gem_version)
                         defined?(ActionController::ForceSSL) ? ActionController::ForceSSL : nil
                       else
                         nil
                       end
    MODULES = [
      AbstractController::Rendering,
      ActionController::Rendering,
      ActionController::Renderers::All,
      ActionController::StrongParameters,
      FORCE_SSL_MODULE,
      ActionController::Instrumentation,
      JSONAPI::ActsAsResourceController
    ].freeze

    MODULES.compact.each do |mod|
      include mod
    end
  end
end
