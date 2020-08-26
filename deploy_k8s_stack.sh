set -e
# clean the staged files for the previous run (if applicable)
rm -rf /opt/k8s  /etc/kubernetes

cd scripts

#./00.sh 2>&1 | tee /tmp/00.log
# |tee casues wrapper contines to next step even the 00.sh called exit 1
# If there is user data error, it should not continue at all.
# so I take away the tee for the 00.sh
./00.sh
# as 00.sh is only validating user inout, no need to redirect to log file

./01.sh 2>&1 | tee /tmp/01.log

./02.sh 2>&1 | tee /tmp/02.log

./03.sh 2>&1 | tee /tmp/03.log

./04.sh 2>&1 | tee /tmp/04.log

./05-01.sh 2>&1 | tee /tmp/05-01.log

./05-02.sh 2>&1 | tee /tmp/05-02.log

./05-03.sh 2>&1 | tee /tmp/05-03.log

./05-04.sh 2>&1 | tee /tmp/05-04.log

./06-01.sh 2>&1 | tee /tmp/06-01.log

./06-02.sh 2>&1 | tee /tmp/06-02.log

./06-03.sh 2>&1 | tee /tmp/06-03.log

./06-04.sh 2>&1 | tee /tmp/06-04.log

./06-05.sh 2>&1 | tee /tmp/06-05.log

./06-06.sh 2>&1 | tee /tmp/06-06.log

./07-test.sh 2>&1 | tee /tmp/07-01.log

# there is no 08-01 as it was a description

./08-02.sh 2>&1 | tee /tmp/08-02.log &
# tee holds the session even though I put the kubectl port-forward command in background
# I don't think there is dependency among the 08-03,08-04,08-05, so it should be ok

./08-03.sh 2>&1 | tee /tmp/08-03.log &

./08-04.sh 2>&1 | tee /tmp/08-04.log &

./08-05.sh 2>&1 | tee /tmp/08-05.log &
