//! Default Compute@Edge template program.

use fastly::http::{ Method, StatusCode};
use fastly::{ Error, Request, Response, Body};
use m3u8_rs::playlist::{Playlist};
use url::Url;

/// The name of a backend server associated with this service.
///
/// This should be changed to match the name of your own backend. See the the `Hosts` section of
/// the Fastly WASM service UI for more information.
const PRIMARY_BACKEND: &str = "primary_backend";

/// The name of a second backend associated with this service.
const SECONDARY_BACKEND: &str = "secondary_backend";

/// The entry point for your application.
///
/// This function is triggered when your service receives a client request. It could be used to
/// route based on the request properties (such as method or path), send the request to a backend,
/// make completely new requests, and/or generate synthetic responses.
///
/// If `main` returns an error, a 500 error response will be delivered to the client.
#[fastly::main]
fn main(mut req: Request) -> Result<Response, Error> {
    // Make any desired changes to the client request.
    let req_clone = req.clone_without_body();
    let req_clone_for_match = req.clone_without_body();

    match (req_clone_for_match.get_method(), req_clone_for_match.get_path()) {
        //When we get the media playlist we will also prefetch a few segments but also modify the playlist
        // to include the media playlist file name as a query param (instead of using cookies and such).
        // We do this so that when the player requests for the ts segment, we fetch the media file again
        // and at every 5 segment interval we use the media playlist to prefetch 5 more segments
        (&Method::GET, url_path) if url_path.ends_with(".m3u8") => {

            let mut be_resp = req.send(PRIMARY_BACKEND)?;
            let url = Url::parse(&req_clone.get_url().to_string())?;
            let mut path_segments = url.path_segments().ok_or_else(|| "cannot be base").unwrap();
            let path_segment_copy = path_segments.clone();
            let file = path_segment_copy.last().unwrap().clone();
            let query_str = "?".to_owned()  + file;

            let len = path_segments.clone().count();
            let mut base_url = req_clone.get_url().host_str().unwrap();
            let mut path_url_vec = vec![];
            path_url_vec.push(base_url);
            for (i, path) in path_segments.enumerate().filter(|&(index, path)| index < len-1) {
                path_url_vec.push(path);

            }
            let mut base_path = "".to_string();
            for path_val in path_url_vec {
                base_path = base_path + path_val + "/";
            }

            if be_resp.get_status() == StatusCode::OK {

                let mut be_resp_body = be_resp.clone_with_body().into_body_bytes();
                    match m3u8_rs::parse_playlist_res(&be_resp_body) {
                    Ok(Playlist::MasterPlaylist(_pl)) => Ok(be_resp),
                    Ok(Playlist::MediaPlaylist(pl)) => {
                        let mut pending_req_vec = vec![];

                        let mut m_playlist = pl.clone();

                        // We modify the MediaSegment vector to include the media file as a query param
                        let mut m_segments = pl.segments.clone();
                        for (index, m_segment) in pl.segments.iter().enumerate() {
                            for c in query_str.chars() {
                                m_segments[index].uri.push(c);
                            }
                        }

                        // We create a new playlist struct with the new MediaSegment vec
                        let playlist_resp = m3u8_rs::playlist::MediaPlaylist{
                            version:pl.version,
                            target_duration:pl.target_duration,
                            media_sequence: pl.media_sequence,
                            segments:m_segments,
                            discontinuity_sequence: pl.discontinuity_sequence,
                            end_list: pl.end_list,
                            playlist_type: pl.playlist_type,
                            i_frames_only: pl.i_frames_only,
                            start: pl.start,
                            independent_segments: pl.independent_segments,
                            unknown_tags: pl.unknown_tags,
                        };

                        // We use the old copy of the playlist for prefetching (doesn't matter if you used the old or new one)
                        for (_index, segment) in m_playlist.segments
                            .iter()
                            .enumerate()
                            .filter(|&(index, _)| index < 6) { // You will go through every item in playlist one by one in the order you requested
                            //.filter(|&(index, segment) | segment.duration

                            // Forward the downstream request to the backend
                            println!("Prefetching this segment in call to playlist {}", format!("{}{}", base_path, segment.uri));
                            //let segment_uri = base_url + segment.uri.;
                            let pending_req_val = fastly::Request::head(format!("https://{}{}", base_path, segment.uri))
                                .send_async(PRIMARY_BACKEND)?;
                            pending_req_vec.push(pending_req_val);
                        }
                        for new_req in pending_req_vec {
                            new_req.wait()?;
                        }
                        //Ok(be_resp)
                        let mut resp_vec= Vec::new();
                        let resp_bytes = playlist_resp.write_to(&mut resp_vec).unwrap();
                        // We respond with the new playlist
                        Ok(Response::new()
                            .with_body(Body::from(resp_vec)))

                    }
                    Err(_e) => Ok(be_resp)
                }
            } else {
                Err (fastly::Error::msg(be_resp.get_status().to_string()))
            }
        }

        (&Method::GET, url_path) if url_path.ends_with(".ts") => {

            let url = Url::parse(&req_clone.get_url().to_string())?;
            let mut path_segments = url.path_segments().ok_or_else(|| "cannot be base").unwrap();
            let path_segment_copy = path_segments.clone();

            // We save the originally requested file name since we will modify this request shortly.
            let file = path_segment_copy.last().unwrap().clone();

            let len = path_segments.clone().count();
            let mut base_url = req_clone.get_url().host_str().unwrap();
            let mut path_url_vec = vec![];
            path_url_vec.push(base_url);
            for (i, path) in path_segments.enumerate().filter(|&(index, path)| index < len-1) {
                path_url_vec.push(path);

            }
            let mut base_path = "".to_string();
            for path_val in path_url_vec {
                base_path = base_path + path_val + "/";
            }

            // If it's a ts segment we get the query param and ask for the m3u8 playlist first. So modify the req uri.
            // Remember we modified and added the playlist file name to query param of every segment in the first part
            req.set_url(Url::parse(format!("https://{}{}", base_path, req_clone.get_query_str().unwrap()).as_str()).unwrap());
            println!("This is the url we will set {}", req.get_url_str());
            let mut be_resp = req.send(PRIMARY_BACKEND)?;
            if be_resp.get_status() == StatusCode::OK {

                // The following is almost the same except we don't modify any response body unlike previously
                // and we also change the prefetch loop filter to always look for 5 segments ahead if and only if
                // the segment number is a multiple of 5. This way you will never see a MISS again
                let mut be_resp_body = be_resp.clone_with_body().into_body_bytes();
                match m3u8_rs::parse_playlist_res(&be_resp_body) {
                    Ok(Playlist::MasterPlaylist(_pl)) => Ok(be_resp),
                    Ok(Playlist::MediaPlaylist(pl)) => {

                        let mut m_playlist = pl.clone();
                        for (index, segment) in m_playlist.segments
                            .iter()
                            .enumerate()
                            //.filter(|&(index, _)| index < 5)
                            .filter(|&(index, segment)| (index % 5 == 0) && index > 0 && segment.uri == file)
                        {
                            println!("This is the segment uri {}, index {} and this is the file name {}", segment.uri, index, file);
                                let mut pending_req_vec = vec![];
                                for (_index, segment) in m_playlist.segments
                                    .iter()
                                    .enumerate()
                                    .filter(|&(new_index, _)| new_index > index && new_index < index + 6)
                                { // You will go through every item in playlist one by one in the order you requested
                                    // Forward the downstream request to the backend
                                    println!("Prefetching this segment in call to ts {}", format!("{}{}", base_path, segment.uri));
                                    //let segment_uri = base_url + segment.uri.;
                                    let pending_req_val = fastly::Request::head(format!("https://{}{}", base_path, segment.uri))
                                        .send_async(PRIMARY_BACKEND)?;
                                    pending_req_vec.push(pending_req_val);
                                }
                                for new_req in pending_req_vec {
                                    new_req.wait()?;
                                }
                        }

                        println!("This is the original ts file {}", format!("https://{}{}", base_path, file));
                        let be_mut_beresp = fastly::Request::get(format!("https://{}{}", base_path, file)).send(PRIMARY_BACKEND)?;
                        Ok(be_mut_beresp)
                    },
                    Err(_e) => {
                        Ok(be_resp)
                    }
                }
            } else {
                Err (fastly::Error::msg(be_resp.get_status().to_string()))
            }
        }
        _ => {

            // Forward the downstream request to the backend
            let mut be_resp = req.send(PRIMARY_BACKEND)?;
            if be_resp.get_status() == StatusCode::OK {
                Ok(be_resp)
            } else {
                Err (fastly::Error::msg(be_resp.get_status().to_string()))
            }
        }
    }
}