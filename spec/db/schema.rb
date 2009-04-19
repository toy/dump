ActiveRecord::Schema.define(:version => 0) do
  create_table :chickens, :force => true do |t|
    %w(string text integer float decimal datetime timestamp time date binary boolean).each do |type|
      t.column "#{type}_col", type
    end
  end
end
