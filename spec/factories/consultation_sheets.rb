FactoryBot.define do
  factory :consultation_sheet do
    patient_name { "MyString" }
    patient_id { "MyString" }
    diagnosis { "MyString" }
    content { "MyText" }
    status { 1 }
    score { "9.99" }
    risk_level { 1 }
    raw_file { "MyText" }
    findings { "" }
  end
end
