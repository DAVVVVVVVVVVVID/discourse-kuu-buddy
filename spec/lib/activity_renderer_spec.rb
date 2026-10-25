# frozen_string_literal: true

RSpec.describe DiscourseKuuBuddy::ActivityRenderer do
  subject(:renderer) { described_class.new(activity) }

  let(:activity) do
    DiscourseKuuBuddy::Activity.new(
      title: "周六一起打麻将",
      capacity: 4,
      schedule: "这周六 19:00 左右",
      requirements: "",
      description: "",
    )
  end

  before { SiteSetting.default_locale = "zh_CN" }

  it "uses the activity as the title" do
    expect(renderer.title).to eq("周六一起打麻将")
  end

  it "lists the fields, with the default requirements when none are given" do
    expect(renderer.raw).to eq(<<~MD.chomp)
      - **时间**：这周六 19:00 左右
      - **人数**：4 人（含发起人）
      - **参加条件**：无条件，欢迎所有人
    MD
  end

  it "adds the description and escapes Markdown in the fields" do
    activity.requirements = "会打*日麻*"
    activity.description = "新手也欢迎\n地点在百万遍"

    expect(renderer.raw).to eq(<<~MD.chomp)
      - **时间**：这周六 19:00 左右
      - **人数**：4 人（含发起人）
      - **参加条件**：会打\\*日麻\\*

      新手也欢迎
      地点在百万遍
    MD
  end
end
