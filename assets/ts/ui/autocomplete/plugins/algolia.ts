import { SearchResponse } from "@algolia/client-search";
import { AutocompleteJSPlugin, debounced } from "../plugins";
import AlgoliaItemTemplate from "../templates/algolia";
import { AutocompleteItem, Item } from "../__autocomplete";

/**
 * Generates a plugin for Algolia Autocomplete which enables searching for our
 * Algolia-backed items given a user-input string. This currently includes GTFS
 * stops, GTFS routes, and content from the CMS. Results from all indexes are
 * fetched together, and rendered with rich iconography associated with the
 * retrieved data types, with matching text depicted in bold. Links navigate to
 * the source URL for the selected data type.
 */
export default function createAlgoliaBackendPlugin(
  algoliaIndexes: string[]
): AutocompleteJSPlugin {
  return {
    getSources({ query }) {
      if (query) {
        return [
          {
            sourceId: "algolia",
            templates: {
              item: AlgoliaItemTemplate
            },
            getItemUrl({ item }) {
              const { url, _content_url } = item as AutocompleteItem;
              return (url || _content_url) as string;
            },
            getItems() {
              return debounced(
                fetch("/search/query", {
                  method: "POST",
                  headers: {
                    "Content-Type": "application/json"
                  },
                  body: JSON.stringify({ algoliaQuery: query, algoliaIndexes })
                })
                  .then(res => res.json())
                  .then(resp =>
                    (resp.results as SearchResponse[]).flatMap(
                      ({ hits, index }) =>
                        hits.map(hit => ({ ...hit, index } as AutocompleteItem))
                    )
                  ),
                300
              );
            }
          }
        ];
      }
      return [];
    }
  };
}
