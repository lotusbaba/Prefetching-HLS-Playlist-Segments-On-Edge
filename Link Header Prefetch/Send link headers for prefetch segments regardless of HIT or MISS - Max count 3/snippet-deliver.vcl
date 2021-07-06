declare local var.ts_ext STRING;
declare local var.segment_num INTEGER;
declare local var.segment_count INTEGER;

if (req.backend.is_shield && req.url.basename ~ "([a-zA-Z]+)([^a-zA-Z.]+).ts") {
  
  set var.segment_num =  std.atoi(re.group.2);
  set var.segment_num += 1;
  log "This is the original object: "req.url;
  log "This is the pushed object: "req.url.dirname "/" re.group.1 std.itoa(var.segment_num) ".ts";
  
  if (http_status_matches(resp.status, "200,304") && req.http.Cookie:segment_count && std.atoi(req.http.Cookie:segment_count) > 0) {
      set var.segment_count = std.atoi(req.http.Cookie:segment_count);
      set var.segment_count -= 1;
      add resp.http.link = "<" req.url.dirname "/" re.group.1 std.itoa(var.segment_num) ".ts" ">; rel=preload; as=image";
      set resp.http.H2LinkHeader =  "link header set";
      set resp.http.Set-Cookie = "segment_count=" var.segment_count "; max-age=600" "; path=/; http-only; secure";
  } else if (http_status_matches(resp.status, "200,304")) { // First time we are seeing this request so set cookie
  set var.segment_count = 3;
    set resp.http.Set-Cookie = "segment_count=" var.segment_count "; max-age=600" "; path=/; http-only; secure";
  }
}