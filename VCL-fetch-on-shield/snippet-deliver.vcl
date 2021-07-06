if (!req.http.noprefetchheader && req.url.basename ~ "([a-zA-Z]+)([^a-zA-Z.]+).ts") {
  declare local var.segment_num INTEGER;
  declare local var.segment_count INTEGER;
  declare local var.iteration INTEGER;
  
  if (req.http.Cookie:segment_count && std.atoi(req.http.Cookie:segment_count) == 0) {
    if (!req.backend.is_shield) {
      set var.segment_count = 3;
    } else {
      set var.segment_count = 4;
    }
    set var.iteration = 0;
  } else if (req.http.Cookie:segment_count) {
    set var.segment_count = std.atoi(req.http.Cookie:segment_count);
    
    if (!req.http.iteration) {
      set var.iteration = 0;
    }
  } else { // Very first time seeing this request. No cookie
    if (!req.backend.is_shield) {
      set var.segment_count = 3;
    } else {
      set var.segment_count = 4;
    }
    set req.http.Cookie = "segment_count=" var.segment_count;
    set var.iteration = 0;
  }
  
  if (!req.backend.is_shield && !req.http.only-edge && !resp.http.edgesegment && req.url.basename ~ "([a-zA-Z]+)([^a-zA-Z.]+).ts") {
    
    set var.segment_num =  std.atoi(re.group.2);
  
    if (http_status_matches(resp.status, "200,304") && req.http.Cookie:segment_count && std.atoi(req.http.Cookie:segment_count) > 0) {
        
        set var.segment_count -= 1;
        
        if (var.segment_count == 0) {
          
          //set var.segment_num -= 1;
          set var.segment_num -= std.atoi(req.http.iteration);
          
        } else {
          set var.segment_num += 2; // make sure iteration increment matches this one
          set var.iteration = std.atoi(req.http.iteration);
          set var.iteration += 2; // make sure segment increment matches this one
          set req.http.iteration = var.iteration;
        }
        
        log "This is the original object: "req.url;
        log "This is the pushed object: "req.url.dirname "/" re.group.1 std.itoa(var.segment_num) ".ts";
    
        set req.url = req.url.dirname "/" re.group.1 std.itoa(var.segment_num) ".ts";
        set req.http.Cookie = "segment_count=" var.segment_count;
        
        if (req.http.fetchedsegments) {
          set req.http.fetchedsegments = req.http.fetchedsegments "," var.segment_num ":" fastly_info.state ": from shield";
        } else {
          set req.http.fetchedsegments = var.segment_num ":" fastly_info.state ": from shield";
        }
        
        set req.http.Fastly-Force-Shield = "1";
        restart;
    } else if (http_status_matches(resp.status, "200,304")  && req.url.basename ~ "([a-zA-Z]+)([^a-zA-Z.]+).ts") { 
      
      set var.segment_num =  std.atoi(re.group.2);
      set var.segment_num -= std.atoi(req.http.iteration);
      set resp.http.edgesegment = var.segment_num;
      set resp.http.fetchedsegments =  req.http.fetchedsegments "," std.atoi(re.group.2) ":" fastly_info.state  ": resp for original req from shield";
      
    }
  } else if (resp.http.edgesegment) { // Only going through this on edge if the response came from shield i.e. it wasn't a HIT

      set var.segment_count -= 1;
      set resp.http.Set-Cookie = "segment_count=" var.segment_count "; max-age=600" "; path=/; http-only; secure";
      
      if (resp.http.fetchedsegments && req.url.basename ~ "([a-zA-Z]+)([^a-zA-Z.]+).ts") {
          set resp.http.fetchedsegments = resp.http.fetchedsegments "," std.atoi(re.group.2) ":" fastly_info.state ":from edge";
        } else if (req.url.basename ~ "([a-zA-Z]+)([^a-zA-Z.]+).ts") {
          set resp.http.fetchedsegments = std.atoi(re.group.2) ":" fastly_info.state ":from edge";
        }
    }
}
set resp.http.Access-Control-Allow-Origin = "*";