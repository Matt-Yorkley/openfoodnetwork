module Admin
  module InjectionHelper
    def admin_inject_enterprise
      admin_inject_json_ams "admin.enterprises", "enterprise", @enterprise, Api::Admin::EnterpriseSerializer
    end

    def admin_inject_payment_methods
      admin_inject_json_ams_array "admin.payment_methods", "paymentMethods", @payment_methods, Api::Admin::IdNameSerializer
    end

    def admin_inject_shipping_methods
      admin_inject_json_ams_array "admin.shipping_methods", "shippingMethods", @shipping_methods, Api::Admin::IdNameSerializer
    end

    def admin_inject_producers
      admin_inject_json_ams_array "ofn.admin", "producers", @producers, Api::Admin::IdNameSerializer
    end

    def admin_inject_json_ams(ngModule, name, data, serializer, opts = {})
      json = serializer.new(data).to_json
      render partial: "admin/json/injection_ams", locals: {ngModule: ngModule, name: name, json: json}
    end

    def admin_inject_json_ams_array(ngModule, name, data, serializer, opts = {})
      json = ActiveModel::ArraySerializer.new(data, {each_serializer: serializer}.merge(opts)).to_json
      render partial: "admin/json/injection_ams", locals: {ngModule: ngModule, name: name, json: json}
    end
  end
end