class RemoveEmailFromEnterprises < ActiveRecord::Migration
  def up
    Enterprise.select([:id, :email]).each do |enterprise|
      contact_user = Spree::User.find_by_email enterprise.email
      unless contact_user
        password = Devise.friendly_token.first(8)
        contact_user = Spree::User.create(email: enterprise.email, password: password, password_confirmation: password)
        contact_user.send_reset_password_instructions
      end

      manager = EnterpriseRole.find_or_initialize_by_user_id_and_enterprise_id(contact_user.id, enterprise.id)
      manager.update_attribute :receives_notifications, true
    end

    remove_columns :enterprises, :email, :contact
  end

  def down
    add_column :enterprises, :email, :string
    add_column :enterprises, :contact, :string

    Enterprise.select(:id).each do |e|
      contact_user = EnterpriseRole.receives_notifications_for(e.id)
      e.update_attribute :email, contact_user.email
    end
  end
end