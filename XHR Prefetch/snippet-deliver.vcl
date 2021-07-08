declare local var.segment_num INTEGER;
declare local var.remainder INTEGER;
declare local var.segment_obj STRING;

// In production services you might want to turn this on only on the edge
//if (req.backend.is_shield && req.url ~ "/([a-zA-Z]+)([^a-zA-Z.]+).ts" && http_status_matches(resp.status, "200,304")) {
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

  if (var.remainder > 0) {
      set resp.http.segmentcount = var.remainder;
  } else {
      set resp.http.segmentcount = "2";
  }
}
set resp.http.Access-Control-Allow-Origin = "*";
set resp.http.Access-Control-Expose-Headers = "fetchedurl, prefetchedsegment, segmentcount";
set resp.http.Access-Control-Allow-Credentials = "true";
