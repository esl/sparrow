PRESET=$1

case $PRESET in
    test)
        mix sparrow.certs.dev
        mix test
        ;;
    test_with_coveralls)
        mix sparrow.certs.dev
        MIX_ENV=test mix coveralls.travis --include system
        ;;
    credo)
        mix credo --strict
        ;;
    dialyzer)
        MIX_ENV=test mix dialyzer --halt-exit-status
        ;;
    *)
        echo "Invalid preset: $PRESET"
        exit 1
        ;;
esac
