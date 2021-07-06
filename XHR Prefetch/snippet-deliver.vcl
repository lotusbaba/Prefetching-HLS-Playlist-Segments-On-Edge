declare local var.segment_num INTEGER;
declare local var.remainder INTEGER;
declare local var.segment_obj STRING;

//if (req.backend.is_shield && fastly_info.state !~ "HIT" && req.url ~ "/([a-zA-Z]+)([^a-zA-Z.]+).ts") {
  if (req.url ~ "/([a-zA-Z]+)([^a-zA-Z.]+).ts" && http_status_matches(resp.status, "200,304")) {

  set var.segment_num =  std.atoi(re.group.2);
  set var.remainder = var.segment_num;
  set var.remainder %= std.atoi(table.lookup(prefetch, "count", "5"));

  if (var.remainder > 0) {
      set var.segment_num += 1;
      set var.segment_obj = re.group.1;
      set resp.http.fetchedurl = "This is the original object: "req.url;
      set resp.http.prefetchedsegment =  req.url.dirname "/" var.segment_obj std.itoa(var.segment_num) ".ts";
  }
  set resp.http.segmentcount = var.remainder;
}
set resp.http.Access-Control-Allow-Origin = "*";
set resp.http.Access-Control-Expose-Headers = "fetchedurl, prefetchedsegment, segmentcount";
set resp.http.Access-Control-Allow-Credentials = "true";