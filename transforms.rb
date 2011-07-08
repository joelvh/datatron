# YAML that did this
#---
#specifications: 
#  default_strategy: &specifications
#    to:
#      product_id :
#        product_number : :product_id
#      name : attribute_name
#      value : attribute_value
#      sequence : seq
#products:
#  default_strategy :
#    to:
#      long_description : detailed_description
#      search_keywords : keywords
#      product_no : product_number
#      short_description_name : description
#      category_page_description : text1
#      marketing_graphic_b : text2
#      ship_charge : weight
#      specifications: *specifications
#    from:
#      born_on_date :
#        created_on : :date_parse
#      /featured_category_[0-9]/ : :add_category
#categories:
#  default_strategy :
#    to:
#      dmi_identifier : cat_nbr
#      sequence : seq
#      canonical_url :
#        urw_text : :canonical_url
#    from:
#      CanonicalURL : false

# RUBY DSL that does this
module Datatron 
  
  module Formats
    class UTF8Excel < ExcelTabDelimitedFile
      class << self
        def new filename
          debugger
          1
          c = super "#{filename}_utf8"
          c.base_name = "#{filename}"
        end
      end
    end
  end

  class Specification < Transform
    default_strategy do
      from_model UTF8Excel 
      to_model Datatron::Formats::ActiveRecord

      to :product_id do |val|
        p = Product.find_by_product_no val
        p.specifications << self 
      end
      done

      to :name
      from :attribute_name
     
      to :value
      from :attribute_value
      
      to :sequence 
      from :seq
    end
  end

  class Product < Transform
    default_strategy do
      from_model UTF8Excel 
      to_model Datatron::Formats::ActiveRecord
        
      to :long_description
      from :detail_description
      
      to :search_keywords
      from :keywords

      to :product_no
      from :product_number

      to :category_page_description
      from :description

      to :marketing_graphic_b
      from :text2

      to :ship_charge
      from :weight

      to :specifications
      using Specification.default_strategy do
        find_by :product_no, as: product_id

        to :seq
        from :sequence
      end

      from :born_on_date 
      to :created_on do |val|
        Date.strptime(val, "%m/%d/%y %H:%M")
      end

      from /featured_category_[0-9]/ do |val|
        categories << Category.find_by_dmi_id(val)
        pc = product_categories.find(val)
        pc.featured = true
        pc.save!
      end
      done

      otherwise :copy
    end
  end

  class Category < Transform
    default_strategy do
      from_model UTF8Excel 
      to_model Datatron::Formats::ActiveRecord
      
      to :dmi_identifier
      from :cat_nbr

      to :sequence
      from :seq

      from :urw_text
      to :canonical_url do |val|
        pretty_router = PrettyRouter.new(:url => val)
      end

      from :CanonicalURL
      delete
    end
  end
end
