# jsonBournemalizer
builds tab-separated, normalized set of records from json data

like this:
        jsonBournemalizer.pl -i [infile] -o [outfile] [-l [logfile]] [-d]

This will ingest a Json array consisting of multiple objects and produce a tab-separated file where each input object is considered a record, and each name/value pair is considered a field/value.  The entire array will be examined to produce a master record template in which all name/fields are represented.  For any object/record which doesn't contain each name/field found, the output record (line) will include the word 'null' as a placeholder.

NB:  Using 'null' is less than ideal since 'null' is one of the valid values in Json, but we're going to live with it for now.  In a future revision, we will use '<NULL>' to indicate the specific name/field was not present in the source Json array.

We expect to see a Json array similar to this:
[{"sing":"song","number":99.9,"state":true,"count":[1,2,3],"pets":{"cat":true,"dog":"rover","rat":null}},{"ding":"dong","numero":1,"state":false,"alphabet":["a","b","c"],"pets":{"cat":false,"dog":"fido","rat":null}}]

Key characteristics are:
        (1) beginning with [{"
        (2) ending with }]
        (3) each object/record being divided by },{
        (4) and the general Json syntactical requirements.  Reference https://datatracker.ietf.org/doc/html/rfc8259.

This does NOT accommodate white space surrounding the structural characters:  { } [ ] : ,.  A future version should allow for such.

The Json objects will only be parsed at their top level.  That is, any values/fields that are arrays or objects will be preserved in the output in their original form.  Perhaps at some point an effort will be made to create subfields (e.g., "pets:cat", "pets:dog", and "pets:rat" from the above exemplar), but don't hold your breath.

This is intended to normalize fairly-similar records within a Json array.
