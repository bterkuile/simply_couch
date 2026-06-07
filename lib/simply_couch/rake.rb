namespace :simply_couch do
  desc "delete all design documents"
  task :delete_design_documents do
    require File.dirname(__FILE__) + "/couch"
    if database = ENV['DATABASE']
      deleted = SimplyCouch::Model.delete_all_design_documents(database)
      puts "deleted #{deleted} design documents in #{database}"
    else
      puts "please specify which database to clear: DATABASE=http://localhost:5984/simply_couch rake simply_couch:delete_design_documents"
    end
  end

  desc "compact all design documents"
  task :compact_design_documents do
    require File.dirname(__FILE__) + "/couch"
    if database = ENV['DATABASE']
      compacted = SimplyCouch::Model.compact_all_design_documents(database)
      puts "triggered compaction of #{compacted} design documents in #{database}"
    else
      puts "please specify which database to clear: DATABASE=http://localhost:5984/simply_couch rake simply_couch:delete_design_documents"
    end
  end
end