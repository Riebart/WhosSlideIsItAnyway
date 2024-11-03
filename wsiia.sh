#!/bin/bash

section=0

while [ true ]
do
    section=$[section+1]
    slide=1

    echo "Getting random page" >&2
    page_name=$(wget -qO- https://en.wikipedia.org/wiki/Special:Random | sed -n 's|<link rel="canonical" href=".*/\(.*\)">|\1|p')

    while [ true ]
    do
        echo "$section.$slide Getting page title for $page_name" >&2
        page_title=$(wget -qO- "https://en.wikipedia.org/w/api.php?format=json&action=query&titles=$page_name" | jq -r '(.query.pages | keys)[0] as $k | .query.pages[$k].title')

        echo "$section.$slide Getting images for $page_name" >&2
        images=$(wget -qO- "https://en.wikipedia.org/w/api.php?format=json&action=query&prop=images&titles=$page_name" | jq -r '(.query.pages | keys)[0] as $k | .query.pages[$k].images | if . == null then null else .[].title end')

        echo "$section.$slide Getting links for $page_name" >&2
        links=$(wget -qO- "https://en.wikipedia.org/w/api.php?format=json&action=query&prop=links&titles=$page_name" | jq -r '(.query.pages | keys)[0] as $k | .query.pages[$k].links[] | .title')

        echo "$section.$slide Removing TLDs from list of acceptable links" >&2
        links=$(echo "$links" | grep -v '^\.[a-z-]*')

        echo "$section.$slide Limiting images to JPG/JPEG and PNG" >&2
        images=$(echo "$images" | grep -iE "\.(png|jpg|jpeg)$")

        echo "$section.$slide Checking image and link counts for $page_name" >&2
        if [ "$images" == "null" ] || [ "$links" == "null" ] || [ "$images" == "" ]
        then
            echo "$section.$slide No images or links found for the current page" >&2
            echo "===============" >&2
            echo "$images" | wc -l >&2
            echo "$links" | wc -l >&2
            break
        fi

        image_name=$(echo "$images" | shuf | head -n1)
        echo "$section.$slide Chosen image name: $image_name" >&2

        echo "$section.$slide Testing linked pages to find one that exists" >&2
        for page in `echo "$links" | shuf | tr ' ' '_'`
        do
            echo "$section.$slide Testing $page" >&2
            missing_page=$(wget -qO- "https://en.wikipedia.org/w/api.php?format=json&action=query&prop=links&titles=$page" | jq '.query.pages | has("-1")')

            if [ "$missing_page" == "false" ]
            then
                next_page=$page
                break
            fi
        done

        if [ "$next_page" == "" ]
        then
            echo "$section.$slide No linked pages exist, restarting" >&2
            break
        fi

        echo "$section.$slide Chosen next page: $next_page" >&2

        image_url=$(wget -qO- "https://en.wikipedia.org/w/api.php?format=json&action=query&prop=imageinfo&iiprop=url&titles=$image_name" | jq -r '(.query.pages | keys)[0] as $k | .query.pages[$k].imageinfo[0].url')
        echo "{\"section\": $section, \"slide\": $slide, \"title\": \"$page_title\", \"image\": \"$image_url\"}"

        page_name=$next_page
        slide=$[slide+1]
    done
done
