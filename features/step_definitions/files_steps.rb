When(/^I execute files:pull$/) do
  Dir.chdir(@src_dir) do
    @out = %x[cap mage:files:pull > /dev/null 2>&1]
  end
end

Then(/^I execute files:push$/) do
  Dir.chdir(@src_dir) do
    @out = %x[cap mage:files:push > /dev/null 2>&1]
  end
end

Then(/^Magento create some assets in media$/) do
  File.open(File.join(@test_files_dir, "deployed", "current", "media", "asset1.jpg"), 'w') {|f|
    f.write "asset1"
  }
  File.open(File.join(@test_files_dir, "deployed", "current", "media", "asset2.jpg"), 'w') {|f|
    f.write "asset2"
  }
end

Then(/^I create some assets locally$/) do
  File.open(File.join(@src_dir, "media", "asset3.jpg"), 'w') {|f|
    f.write "asset3"
  }
end


Then(/^the local media directory should be synced$/) do
    nb_files = Dir[File.join(@src_dir, "media", '**', '*')].count { |file| File.file?(file) }

    nb_files.should == 3
    File.exists?(File.join(@src_dir, "media", "asset1.jpg")).should be_true
    File.exists?(File.join(@src_dir, "media", "asset2.jpg")).should be_true
    File.exists?(File.join(@src_dir, "media", "asset3.jpg")).should be_true
end

Then(/^the remote media directory should be synced$/) do
    nb_files = Dir[File.join(@test_files_dir, "deployed", "current", "media", '**', '*')].count { |file| File.file?(file) }

    nb_files.should == 1
    File.exists?(File.join(@test_files_dir, "deployed", "current", "media", "asset3.jpg")).should be_true
end
