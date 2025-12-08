FactoryBot.define do
  factory :audit_batch do
    name { "MyString" }
    status { 1 }
    total_sheets { 1 }
    processed_sheets { 1 }
  end
end
