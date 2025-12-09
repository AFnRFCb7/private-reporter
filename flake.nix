
{
    inputs = { } ;
    outputs =
        { self } :
            {
                lib =
                    {
                        failure ,
                        pkgs
                    } :
                        let
                            implementation =
                                {
                                    channel ,
                                    private ,
                                    resolution
                                } :
                                    let
                                        application =
                                            pkgs.writeShellApplication
                                                {
                                                    name = "private-reporter" ;
                                                    runtimeInputs =
                                                        [
                                                            pkgs.redis
                                                            pkgs.yq-go
                                                            failure
                                                            (
                                                                pkgs.writeShellApplication
                                                                    {
                                                                        name = "iteration" ;
                                                                        runtimeInputs =
                                                                            [
                                                                                pkgs.coreutils
                                                                                pkgs.git
                                                                                pkgs.libuuid
                                                                                failure
                                                                            ] ;
                                                                        text =
                                                                            let
                                                                                in
                                                                                    ''
                                                                                        MESSAGE="$*"
                                                                                        UUID="$( uuidgen )" || failure 5fa834fd
                                                                                        BRANCH="$( echo "issue/$UUID" | cut --characters 1-64 )" || failure 5deab959
                                                                                        PRIVATE=${ private }
                                                                                        git -C "$PRIVATE" checkout -b "$BRANCH"
                                                                                        git -C "$PRIVATE" -am "$MESSAGE" --alllow-empty --allow-empty-message
                                                                                        git -C "$PRIVATE" push origin HEAD
                                                                                    '' ;
                                                                    }
                                                            )
                                                        ] ;
                                                    text =
                                                        ''
                                                            redis-cli SUBSCRIBE ${ channel } | while read -r TYPE
                                                            do
                                                                if [[ "$TYPE" == "message" ]]
                                                                then
                                                                    read -r CHANNEL
                                                                    if [[ ${ channel } == "$CHANNEL" ]]
                                                                    then
                                                                        read -r PAYLOAD
                                                                        TYPE_="$( yq eval ".type" <<< "$PAYLOAD" - )" || failure 2ee1309a
                                                                        if [[ "resolve-init" == "$TYPE_" ]] || [[ "resolve-release" == "$TYPE_" ]]
                                                                        then
                                                                            RESOLUTION="$( yq eval ".resolution" - <<< "$PAYLOAD" )" || failure 629c9f6a
                                                                            if [[ "${ resolution }" == "$RESOLUTION" ]]
                                                                            then
                                                                                ARGUMENTS_JSON="$( yq eval ".arguments // [ ]" - <<< "$PAYLOAD" )" || failure c9430185
                                                                                readarray -t ARGUMENTS <<< "$ARGUMENTS_JSON"
                                                                                iteration "${ builtins.concatStringsSep "" [ "$" "{" "ARGUMENTS[@]" "}" ] }"
                                                                            fi
                                                                        fi
                                                                    fi
                                                                fi
                                                            done
                                                        '' ;
                                                } ;
                                        in "${ application }/bin/private-reporter" ;
                            in
                                {
                                    check =
                                        {
                                            channel ? "07469d75" ,
                                            expected ? "f11ad4e3" ,
                                            private ? "32b93ceb" ,
                                            resolution ? "b25f40b3"
                                        } :
                                            pkgs.stdenv.mkDerivation
                                                {
                                                    installPhase = ''execute-test "$out"'' ;
                                                    name = "check" ;
                                                    nativeBuildInputs =
                                                        [
                                                            (
                                                                let
                                                                    observed =
                                                                        builtins.toString
                                                                            (
                                                                                implementation
                                                                                    {
                                                                                        channel = channel ;
                                                                                        private = private ;
                                                                                        resolution = resolution ;
                                                                                    }
                                                                            ) ;
                                                                    in
                                                                        if expected == observed then
                                                                            pkgs.writeShellApplication
                                                                                {
                                                                                    name = "execute-test" ;
                                                                                    runtimeInputs = [ pkgs.coreutils ] ;
                                                                                    text =
                                                                                        ''
                                                                                            OUT="$1"
                                                                                            touch "$OUT"
                                                                                        '' ;
                                                                                }
                                                                        else
                                                                            pkgs.writeShellApplication
                                                                                {
                                                                                    name = "execute-test" ;
                                                                                    runtimeInputs = [ failure ] ;
                                                                                    text =
                                                                                        ''
                                                                                            failure 8c67cfa1 resource-reporter "We expected to see ${ expected } but we observed ${ observed }"
                                                                                        '' ;
                                                                                }
                                                            )
                                                        ] ;
                                                    src = ./. ;
                                                } ;
                                    implementation = implementation ;
                                } ;
            } ;
}