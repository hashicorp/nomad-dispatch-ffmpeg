
vagrant:
	vagrant up

terraform:
	cd tf; terraform apply
	cd tf; export NOMAD_ADDR=`terraform output nomad_addr`

destroy:
	cd tf; terraform destroy

submit_one:
	./bin/dispatch.sh samples/one.txt

submit_few:
	./bin/dispatch.sh samples/few.txt

submit_many:
	./bin/dispatch.sh samples/many.txt

