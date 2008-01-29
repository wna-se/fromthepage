class ArticlesHaveGraphs < ActiveRecord::Migration
  def self.up
    add_column :articles, :graph_image, :string
  end

  def self.down
    remove_column :articles, :graph_image
  end
end
