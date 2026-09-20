# Station identity crosswalk

`dim_station.csv` is the authoritative station-identity input. It separates
two concepts:

- `station_member_id` identifies one officially named station member;
- `station_id` identifies the physical interchange complex to which that
  member belongs.

Most complexes contain one named member, so both identifiers are equal.
Consolação and Paulista are the important counterexample: they retain their
official names but share the `consolacao-paulista` complex identifier.

Complex membership is curated from official network sources recorded in
`complex_source`. Neither distance nor name equality creates an interchange.
Geometry may be used to flag candidates for review, but a candidate changes
the crosswalk only after an official source confirms the connection.

`dim_station_alias.csv` maps each raw source name to a `station_member_id`.
Renames and source-specific spellings belong there; physical-complex decisions
belong in `dim_station.csv`.

Commercial sponsor names map back to the plain station name so published data
does not change when sponsorship changes. Honorific renames map forward to the
current official name: for example, `Liberdade` resolves to
`Japão-Liberdade`.
