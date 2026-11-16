FROM alpine:3.22.2@sha256:4b7ce07002c69e8f3d704a9c5d6fd3053be500b7f1c69fc0d80990c2ad8dd412

RUN apk add --no-cache build-base ca-certificates unzip git subversion \
    lua5.1=5.1.5-r13 lua5.1-dev=5.1.5-r13 luarocks5.1=3.11.1-r0 \
    && luarocks-5.1 install argparse 0.7.2-1 \
    && luarocks-5.1 install luafilesystem 1.9.0-1 \
    && luarocks-5.1 install lua_cliargs 3.0.2-1 \
    && luarocks-5.1 install luasystem 0.7.1-1 \
    && luarocks-5.1 install dkjson 2.11-1 \
    && luarocks-5.1 install say 1.4.1-3 \
    && luarocks-5.1 install luassert 1.9.0-1 \
    && luarocks-5.1 install lua-term 0.8-1 \
    && luarocks-5.1 install penlight 1.15.0-1 \
    && luarocks-5.1 install mediator_lua 1.1.2-0 \
    && luarocks-5.1 install luacheck 1.2.0-1 \
    && luarocks-5.1 install busted 2.3.0-1 \
    && luarocks-5.1 install cluacov 0.1.4-1 \
    && luarocks-5.1 install luacov 0.16.0-1

# The libraries and Blizzard UI source the tests load, fetched by fetch_deps.sh (a volume, never the repository).
VOLUME /deps
WORKDIR /addon
ENTRYPOINT ["sh", ".github/validation/check.sh"]
CMD ["test"]
