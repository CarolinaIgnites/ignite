## Make sure your submodules are at HEAD
You want to be working with the most recent code yeah?

## Create the container
./create.sh

## Run the container
nixos-container start ignite

## Test that the services are working
curl editor.ignite.code --resolve 'editor.ignite.code:80:<ip>'
curl api.ignite.code --resolve 'api.ignite.code:80:<ip>'

## Visit the services in browser with your normal set up
