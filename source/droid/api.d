module droid.api;

import std.conv;

import vibe.http.client,
       vibe.data.json,
       vibe.core.log;

import droid.droidversion,
       droid.data;

class API
{
    enum DEFAULT_BASE_URL   = "https://discordapp.com/api";
    enum DEFAULT_USER_AGENT = "DiscordBot (https://github.com/y32/droid, " ~ VERSION ~ ")";

    private immutable string baseUrl_;
    private immutable string token_;
    private immutable string tokenProper_;
    private immutable string userAgent_;

    this(in string token, in string baseUrl = DEFAULT_BASE_URL, in string userAgent = DEFAULT_USER_AGENT)
    {
        token_       = token;
        tokenProper_ = makeTokenProper(token);
        baseUrl_     = baseUrl;
        userAgent_   = userAgent;
    }

    User getUser(in Snowflake id)
    {
        return deserializeDataObject!User(fetch(HTTPMethod.GET, text("/users/", cast(ulong) id)));
    }

    Json fetch(in HTTPMethod method, in string path, in Json postData = Json.emptyObject)
    in
    {
        if (postData.length == 0) assert(method == HTTPMethod.GET);
    }
    body
    {
        import vibe.stream.operations : readAllUTF8;

        return makeRequest!Json(
            makeAPIUrl(path),
            method,
            (scope req) {
                if (postData.length != 0) {
                    req.writeJsonBody(postData);
                }
            },
            (scope res) {
                auto j = res.readJson();
                logDebug("[API] fetch %s: %s", path, j.toPrettyString());
                return j;
            }
        );
    }

    final inout(string) token() @property @safe @nogc inout pure
    {
        return token_;
    }

    private R makeRequest(R)(
        in string url,
        in HTTPMethod method,
        scope void delegate(scope HTTPClientRequest) requester,
        scope R delegate(scope HTTPClientResponse) responder
    )
    {
        R toReturn;

        requestHTTP(
            url,
            (scope req) {
                req.method = method;

                req.headers["Authorization"] = tokenProper_;
                req.headers["User-Agent"]    = userAgent_;

                requester(req);
            },
            (scope res) {
                toReturn = responder(res);
            }
        );

        return toReturn;
    }

    pragma(inline, true)
    private string makeTokenProper(in string token) @safe const pure
    {
        import std.algorithm.searching : startsWith;

        return token.startsWith("Bot", "Bearer") ? token : "Bot " ~ token;
    }

    pragma(inline, true)
    private string makeAPIUrl(in string[] paths...)
    {
        import std.array : join;

        return baseUrl_ ~ join(paths, "/");
    }
}