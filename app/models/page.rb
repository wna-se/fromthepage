# t.column :title, :string, :limit => 255
# # transcription source (rudimentary for this version)
# t.column :transcription, :text
# # image info
# t.column :base_image, :string, :limit => 255
# t.column :base_width, :integer
# t.column :base_height, :integer
# t.column :shrink_factor, :integer
# # foreign keys
# t.column :work_id, :integer
# # automated stuff
# t.column :created_on, :datetime
# t.column :position, :integer
# t.column :lock_version, :integer, :default => 0

class Page < ActiveRecord::Base
  include XmlSourceProcessor
  before_update :process_source
  
  belongs_to :work
  acts_as_list :scope => :work

  has_many :page_article_links
  has_many :articles, :through => :page_article_links
  has_many :page_versions, :order => :page_version

  acts_as_restful_commentable
  
  after_save :create_version
  
  def collection
    work.collection
  end


  # we need a short pagename for index entries
  # in this case this will refer to an entry without
  # superfluous information that would be redundant
  # within the context of a chapter
  # TODO: convert to use a regex stored on the work
  def title_for_print_index
    if title.match(/\w+\W+\w+\W+(\w+)/)
      $1
    else
      title
    end
  end

  # extract a chapter name from the page title
  # TODO: convert to use a regex stored on the work
  def chapter_for_print
    parts = title.split
    if parts.length > 1
      parts[1]
    else
      title
    end
  end


  def scaled_image(factor = 2)
    if 0 == factor
      self[:base_image]
    else
      self[:base_image].sub(/.jpg/, "_#{factor}.jpg")
    end
  end


  def create_version
    version = PageVersion.new
    version.page = self
    version.title = self.title
    version.transcription = self.source_text
    version.xml_transcription = self.xml_text
    version.user = User.current_user
    
    # now do the complicated version update thing
    version.work_version = self.work.transcription_version
    self.work.increment!(:transcription_version)    

    previous_version = 
      PageVersion.find(:first, 
                       :conditions => ["page_id = ?", self.id],
                       :order => "page_version DESC")
    if previous_version
      version.page_version = previous_version.page_version + 1
    end
    version.save!      
  end
  
  # This deletes all graphs within associated articles
  # It should be called twice whenever a page is changed
  # once to reset the previous links, once to reset new links
  def clear_article_graphs
    Article.update_all('graph_image=NULL', 
                       "id in (select article_id "+
                       "       from page_article_links "+
                       "       where page_id = #{self.id})")
  end

  
  #######################
  # XML Source support
  #######################
  
  def clear_links
    # first use the existing links to blank the graphs
    self.clear_article_graphs
    # clear out the existing links to this page
    PageArticleLink.delete_all("page_id = #{self.id}")     
  end

  def create_link(article, display_text)
    link = PageArticleLink.new(:page => self,
                               :article => article,
                               :display_text => display_text)
    link.save!
    return link.id        
  end


end