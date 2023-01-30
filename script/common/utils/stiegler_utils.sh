#!/bin/bash

function determine_environment() {

    select environment in Production Development; do
        if [ "$environment" = 'Production' ]; then
            ENV="production"

        elif [ "$environment" = 'Development' ]; then
            ENV="development"

        fi

    done

    echo "You are now in a $environment Environment" # arguments are accessible through $1, $2,...
}

function copy_docker_override() {
    if [ "$ENV" = 'production' ]; then
        cp config/docker-compose.production.override.yml.example ./docker-compose.production.override.yml

    elif [ "$ENV" = 'development' ]; then
        cp config/docker-compose.override.yml.example ./docker-compose.override.yml
    fi
}

function setup_dotenv() { #this was mostly written with chatGPT

    # Check if the .env file exists
    if [ -f ".env" ]; then
        # Get the value of the COMPOSE_FILE key
        COMPOSE_FILE=$(grep -oP '(?<=COMPOSE_FILE=)[^ ]+' .env)
        if [ "$ENV" == "production" ]; then
            if [[ "$COMPOSE_FILE" == *"production"*"production" ]]; then
                echo "Production files are being used."
            else
                echo "COMPOSE_FILE=$COMPOSE_FILE"
                echo "You are not using the correct files for Production environment. Do you want to change the setting to use Production files? (y/N)"
                read -r choice
                if [ "$choice" == "y" ]; then
                    sed -i 's/COMPOSE_FILE=[^ ]*/COMPOSE_FILE=docker-compose.production.yml:docker-compose.production.override.yml' .env
                    echo "Setting changed to use Production files."
                fi
            fi
        elif [ "$ENV" == "development" ]; then
            if [[ "$COMPOSE_FILE" == *"dev"* ]]; then
                echo "Development files are being used."
            else
                echo "COMPOSE_FILE=$COMPOSE_FILE"
                echo "You may not be using the correct files for Development environment. Do you want to stop and change the setting to use Development files? (y/N)"
                read -r choice
                if [ "$choice" == "y" ]; then
                    exit 1
                fi
            fi
        else
            echo "Unknown value for environment."
            exit 1
        fi
    else
        echo ".env file not found. creating it. "
        cp sample.env .env
        echo "Please Setup your .env File with your parameters."
        exit 1
    fi
}

function prod_assets() {
    run_command bundle exec rake js:webpack_production

}

function get_commit_hash() {
    git_commit_hash=$(git rev-parse HEAD)
    echo "Current git commit hash: $git_commit_hash"
    export git_commit_hash
}

function check_uncommitted_changes() {
    # Use git status to check for uncommitted changes
    git status --porcelain >/dev/null
    if [ $? -ne 0 ]; then
        # if there are uncommitted changes, set the flag
        export uncommitted_changes=1
        echo "There are uncommitted changes. Please commit or stash your changes before proceeding."
    else
        export uncommitted_changes=0
        echo "No uncommitted changes found."
    fi
}

function build_docker_compose_image() {
    check_uncommitted_changes
    if [ $uncommitted_changes -eq 1 ]; then
        echo "Please commit or stash your changes before building the image."
        return
    fi

    get_git_commit_hash
    current_time=$(date +"%Y-%m-%d_%H-%M-%S")
    image_name="dockerizedCanvas:$current_time-$git_commit_hash"
    echo "Building image: $image_name"

    # Start the timer
    start_time=$(date +%s)

    # Build the image
    docker-compose build --pull --force-rm --no-cache --label "build_time=$current_time" --label "git_commit=$git_commit_hash"

    # End the timer
    end_time=$(date +%s)
    build_time=$((end_time - start_time))

    echo "Image $image_name built successfully in $build_time seconds."
}
