issues_file = ARGV[0]
File.open(issues_file).each do |line|
  tokens = line.split(',')
  reason = tokens[12].split('Bike Status:')[0]
  issue_code = ",,,"
  if tokens[9] == '' then
    unless reason.nil?
      case reason.downcase
      when /kickstand/
        issue_code = ",13,kickstand,"  
      when /fender/
        issue_code = ",11,fender,"
      when /frame/
        issue_code = ",1,frame,"
      when /handlebar/
        issue_code = ",3,handlebar,"   
      when /basket/
        issue_code = ",9,basket,"
      when /wheel/
        issue_code = ",12,wheel,"
      when /gear/ , /chain/, /shift/
        issue_code = ",4,gear,"
      when /brake/, /break/
        issue_code = ",5,brake,"
      when /battery/
        issue_code = ",15,battery,"
      when /lights/
        issue_code = ",14,lights,"
      when /still/
        issue_code = ",21,app," 
      when /seat /
        issue_code = ",2,seat,"
      when /lock/
        issue_code = ",6,lock,"
      
      end

    end
    
     puts tokens[0..8].join(',') + issue_code + tokens[10..12].join(',')
  else
     puts tokens[0..9].join(',') + ",," + tokens[10..12].join(',')
  end
  
end