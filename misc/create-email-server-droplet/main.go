package main

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/aws/aws-lambda-go/cfn"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/route53"

	"github.com/aws/aws-sdk-go/service/eventbridge"
	"github.com/aws/aws-sdk-go/service/ssm"
	"github.com/digitalocean/godo"
)

func RefString(v string) *string { return &v }

func createDroplet(ctx context.Context, request cfn.Event) (physicalResourceID string, data map[string]interface{}, err error) {

	client := godo.NewFromToken(os.Getenv("DIGITALOCEAN_API_TOKEN"))
	sess := session.Must(session.NewSession())
	eventBridgeClient := eventbridge.New(sess)

	parameterName, ok := request.ResourceProperties["ParameterName"].(string)
	if !ok {
		return request.PhysicalResourceID, map[string]interface{}{}, fmt.Errorf("error conversion")
	}

	// If this is a delete request, delete the droplet and the ssm parameter.
	if request.RequestType == cfn.RequestDelete {

		ssmClient := ssm.New(sess)

		ssmOutput, err := ssmClient.GetParameter(&ssm.GetParameterInput{
			Name: &parameterName,
		})
		if err != nil {
			return request.PhysicalResourceID, map[string]interface{}{}, err
		}

		dropletId, err := strconv.Atoi(*ssmOutput.Parameter.Value)
		if err != nil {
			return request.PhysicalResourceID, map[string]interface{}{}, err
		}

		// Deleting the droplet..
		_, err = client.Droplets.Delete(context.TODO(), dropletId)
		if err != nil {
			return request.PhysicalResourceID, map[string]interface{}{}, err
		}

		// Deleting the ssm parameter..
		_, err = ssmClient.DeleteParameter(&ssm.DeleteParameterInput{
			Name: &parameterName,
		})
		if err != nil {
			return request.PhysicalResourceID, map[string]interface{}{}, err
		}

		// Deleting the eventbridge rule (removing targets first then deleting the rule)..
		_, err = eventBridgeClient.RemoveTargets(&eventbridge.RemoveTargetsInput{
			Rule: &parameterName,
			Ids:  []*string{RefString(parameterName + "-lambda")},
		})
		if err != nil {
			return request.PhysicalResourceID, map[string]interface{}{}, err
		}

		_, err = eventBridgeClient.DeleteRule(&eventbridge.DeleteRuleInput{
			Name: &parameterName,
		})
		if err != nil {
			return request.PhysicalResourceID, map[string]interface{}{}, err
		}

		// Delete DNS Zone mail records.
		route53Client := route53.New(sess)

		// Getting the zone apex.
		sliceOfStrings := strings.Split(parameterName, "-")
		dnsZoneApex := sliceOfStrings[len(sliceOfStrings)-1]

		// Getting the hosted zone id.
		hostdZoneIdOutput, err := ssmClient.GetParameter(&ssm.GetParameterInput{
			Name: RefString("HostedZoneId"),
		})
		if err != nil {
			fmt.Println(err)
			return request.PhysicalResourceID, map[string]interface{}{}, err
		}

		// Getting the IP of the droplet.
		ipOfDropletOutput, err := ssmClient.GetParameter(&ssm.GetParameterInput{
			Name: RefString("DropletIP"),
		})
		if err != nil {
			fmt.Println(err)
			return request.PhysicalResourceID, map[string]interface{}{}, err
		}

		deletionParams := &route53.ChangeResourceRecordSetsInput{
			ChangeBatch: &route53.ChangeBatch{
				Changes: []*route53.Change{
					{
						Action: RefString("DELETE"),
						ResourceRecordSet: &route53.ResourceRecordSet{
							Name: RefString(dnsZoneApex),
							Type: RefString("MX"),
							ResourceRecords: []*route53.ResourceRecord{
								{
									Value: RefString("10 mail"),
								},
							},
							TTL: aws.Int64(300),
						},
					},
					{
						Action: RefString("DELETE"),
						ResourceRecordSet: &route53.ResourceRecordSet{
							Name: RefString("mail." + dnsZoneApex),
							Type: RefString("A"),
							ResourceRecords: []*route53.ResourceRecord{
								{
									Value: RefString(*ipOfDropletOutput.Parameter.Value),
								},
							},
							TTL: aws.Int64(300),
						},
					},
				},
			},
			HostedZoneId: hostdZoneIdOutput.Parameter.Value,
		}

		// Deleting the record sets.
		_, err = route53Client.ChangeResourceRecordSets(deletionParams)
		if err != nil {
			fmt.Println(err)
			return request.PhysicalResourceID, map[string]interface{}{}, err
		}

		// Deleting the HostedZoneId parameter
		_, err = ssmClient.DeleteParameter(&ssm.DeleteParameterInput{
			Name: RefString("HostedZoneId"),
		})
		if err != nil {
			return request.PhysicalResourceID, map[string]interface{}{}, err
		}

		return request.PhysicalResourceID, map[string]interface{}{}, nil
	}

	// Otherwise, create the droplet.
	dropletName, ok := request.ResourceProperties["DropletName"].(string)
	if !ok {
		return request.PhysicalResourceID, map[string]interface{}{}, fmt.Errorf("error conversion")
	}

	sshKeyFingerprint, ok := request.ResourceProperties["DropletSSHKey"].(string)
	if !ok {
		return request.PhysicalResourceID, map[string]interface{}{}, fmt.Errorf("error conversion")
	}

	createRequest := &godo.DropletCreateRequest{
		Name:   dropletName,
		Region: "ams3",
		Size:   "s-1vcpu-1gb",
		Image: godo.DropletCreateImage{
			Slug: "ubuntu-22-10-x64",
		},
		SSHKeys: []godo.DropletCreateSSHKey{{
			Fingerprint: sshKeyFingerprint,
		}},
	}

	myDroplet, _, err := client.Droplets.Create(context.TODO(), createRequest)
	if err != nil {
		return request.PhysicalResourceID, map[string]interface{}{}, err
	}

	// Creating eventbridge rule.
	schedule := time.Now().Add(time.Minute * 2)

	_, err = eventBridgeClient.PutRule(&eventbridge.PutRuleInput{
		Description:        RefString("Trigger a lamdba function to get IP of the emailserver droplet and create the mail DNS record."),
		Name:               &parameterName,
		State:              RefString("ENABLED"),
		ScheduleExpression: RefString(fmt.Sprintf("cron(%d %d %d %d ? %d)", schedule.Minute(), schedule.Hour(), schedule.Day(), int(schedule.Month()), schedule.Year())),
	})
	if err != nil {
		return request.PhysicalResourceID, map[string]interface{}{"DropletId": myDroplet.ID}, err
	}

	// Putting the lambda function as a target to the rule.
	putTargetOutput, err := eventBridgeClient.PutTargets(&eventbridge.PutTargetsInput{
		Rule: &parameterName,
		Targets: []*eventbridge.Target{{
			Arn:   RefString(request.ResourceProperties["GetDropletIpFunctionArn"].(string)),
			Id:    RefString(parameterName + "-lambda"),
			Input: RefString(fmt.Sprintf("{\"ParameterName\":\"%s\"}", parameterName)),
		}},
	})

	if err != nil || *putTargetOutput.FailedEntryCount != 0 {
		return request.PhysicalResourceID, map[string]interface{}{"DropletId": myDroplet.ID}, err
	}

	return request.PhysicalResourceID, map[string]interface{}{"DropletId": myDroplet.ID}, nil
}

func main() {
	lambda.Start(cfn.LambdaWrap(createDroplet))
}
