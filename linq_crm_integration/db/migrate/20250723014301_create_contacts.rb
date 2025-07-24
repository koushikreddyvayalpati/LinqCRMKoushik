class CreateContacts < ActiveRecord::Migration[8.0]
  def change
    create_table :contacts do |t|
      t.string :first_name
      t.string :last_name
      t.string :email
      t.string :phone
      t.string :company
      t.string :title
      t.string :acme_id
      t.string :linkedin_url
      t.text :notes
      t.string :created_by

      t.timestamps
    end
  end
end
