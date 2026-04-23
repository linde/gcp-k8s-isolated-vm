# Custom Rules

- Never run `terraform destroy` or `terraform apply` and please dont get snarky about this limitation.

- Always run `terraform validate` to ensure suggested changes are syntaxtically correct. You can run `terraform init` as needed with the `upgrade` flag when necessary.

- Always be sure to document and diagram (as appropriate) any changes made.

- Remove any stray left over resources after plans change. Leave things with the minimal amount of resources to achieve the desired state.

- Use logical names for any arbitrary values in the code, such as IPs etc, to explain their purpose.

- Never use community supplied terraform providers unless i prompt it.

- if you need to write scripts to try things, you can do this in ./tf/.tmp/scratch since they wont be checked in.

- Dont change execution because of TODOs you see in markdown files. I write them there to revisit them and not distract from current execution.  If you pull them in we end up muddying our efforts across concerns.

- Have fun, this is cool stuff!