# jr (json repl)

This is half of a project; current status is that you can pipe JSON to stdin,
then inspect/view the contents. After quiting, the JSON is printed to stdout.

The eventual goal is to let you modify the JSON & have the results output for
additional processing.

# Building & Install

- Install nim (https://nim-lang.org/)
- Run `nimble build` from the repository root
- Add the executable to your path

# Synopsis

Assuming a JSON file that looks like:

    $ cat test.json
    {
      "title" : "My Report",
      "fields": [
        { "label" : "n0", "value": 15 },
        { "label" : "n1", "value": 13.5 },
        { "label" : "n2", "value": 7, "invalid" : true }
      ]
    }

You can pipe it to `jr` and inspect by using the `keys` command, or by typing
a pattern in directly:

    $ cat test.json | jr
    > keys
    title: String
    fields: Array
    > title
    title: "My Report"
    > fields.*.value
    fields.0.value: 15
    fields.1.value: 13.5
    fields.2.value: 7
    > fields.*.{label,invalid}
    fields.0.label: "n0"
    fields.1.label: "n1"
    fields.2.label: "n2"
    fields.2.invalid: true
    > fields.2
    fields.2: {
      "label": "n2",
      "value": 7,
      "invalid": true
    }
    > keys fields.2
    fields.2.label: String
    fields.2.value: Int
    fields.2.invalid: Bool
    >

When you exit (via Ctrl-D or Ctrl-C), the JSON is dumped to stdout.

# TODO

- pass path/filter on the commandline to winnow things down
- use hints/completion from latest version of linenoise (need to copy in source
  from antirez)
- allow manipulation/modification of the JSON before outputting the result
