class AddRestaurantToOperationalResources < ActiveRecord::Migration[8.1]
  def change
    %i[categories products orders].each do |table|
      add_reference table, :restaurant, foreign_key: true
    end
  end
end
