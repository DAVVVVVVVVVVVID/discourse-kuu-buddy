# frozen_string_literal: true

module PageObjects
  module Modals
    # 发帖和修改共用的找搭子表单（界面 2）
    class KuuBuddyActivityForm < PageObjects::Modals::Base
      MODAL_SELECTOR = ".kuu-buddy-form-modal"

      def initialize
        super(modal_selector: MODAL_SELECTOR)
      end

      def form
        PageObjects::Components::FormKit.new("#{MODAL_SELECTOR} .kuu-buddy-form")
      end

      def fill_in(name, value)
        form.field(name).fill_in(value)
        self
      end

      def increase_capacity
        find("#{MODAL_SELECTOR} .kuu-buddy-stepper__increase").click
        self
      end

      def decrease_capacity
        find("#{MODAL_SELECTOR} .kuu-buddy-stepper__decrease").click
        self
      end

      def has_capacity?(count)
        has_css?("#{MODAL_SELECTOR} .kuu-buddy-stepper__value", text: count.to_s)
      end

      def has_capacity_hint?(text)
        has_css?("#{MODAL_SELECTOR} .kuu-buddy-stepper__hint", text:)
      end

      def submit
        find("#{MODAL_SELECTOR} .kuu-buddy-form-modal__submit").click
      end

      def has_field_error?(name)
        has_css?("#{MODAL_SELECTOR} .form-kit__field[data-name='#{name}'] .form-kit__errors")
      end
    end
  end
end
