declare local var.segment_num INTEGER;
declare local var.segment_count INTEGER;

if (req.backend.is_shield && fastly_info.state !~ "HIT" && req.url ~ "/([a-zA-Z]+)([^a-zA-Z.]+).ts") {

  set var.segment_num =  std.atoi(re.group.2);
  set var.segment_num += 1;
  set resp.http.fetchedurl = "This is the original object: "req.url;
  set resp.http.pre-fetched-segment =  req.url.dirname "/" re.group.1 std.itoa(var.segment_num) ".ts";

  if (http_status_matches(resp.status, "200,304") && req.http.Cookie:segment_count && std.atoi(req.http.Cookie:segment_count) > 0) {
      set var.segment_count = std.atoi(req.http.Cookie:segment_count);
      set var.segment_count -= 1;
      add resp.http.link = "<" req.url.dirname "/" re.group.1 std.itoa(var.segment_num) ".ts" ">; rel=preload; as=image";
      set resp.http.H2LinkHeader =  "link header set";
      set resp.http.Set-Cookie = "segment_count=" var.segment_count "; max-age=600" "; path=/; http-only; secure";
  } else if (http_status_matches(resp.status, "200,304")) { // First time we are seeing this request so set cookie
  set var.segment_count = 6;
    set resp.http.Set-Cookie = "segment_count=" var.segment_count "; max-age=600" "; path=/; http-only; secure";
  }
}
set resp.http.Access-Control-Allow-Origin = "*";
set resp.http.Access-Control-Expose-Headers = "fetchedurl, pre-fetched-segment";