package main

import (
	"context"
	"fmt"
	"os"
	"strconv"
	"strings"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/route53"
	"github.com/aws/aws-sdk-go/service/ssm"

	"github.com/digitalocean/godo"
)

func RefString(v string) *string { return &v }

func RefBool(v bool) *bool { return &v }

type Request struct {
	ParameterName string `json:"ParameterName"`
}

func getIpOfDroplet(ctx context.Context, request Request) error {

	// Creating digitalocean and aws clients.
	client := godo.NewFromToken(os.Getenv("DIGITALOCEAN_API_TOKEN"))
	sess := session.Must(session.NewSession())
	ssmClient := ssm.New(sess)
	route53Client := route53.New(sess)

	// Fetching the parameter value (id of the droplet).
	parameterName := request.ParameterName
	ssmOutput, err := ssmClient.GetParameter(&ssm.GetParameterInput{
		Name: &parameterName,
	})
	if err != nil {
		return err
	}

	// Getting the droplet.
	dropletId, err := strconv.Atoi(*ssmOutput.Parameter.Value)
	if err != nil {
		return err
	}

	droplet, _, err := client.Droplets.Get(context.TODO(), dropletId)
	if err != nil {
		return err
	}

	// Checking on the ipv4 addresses.
	if len(droplet.Networks.V4) == 0 {
		return fmt.Errorf("no ips associated with the droplet")
	}

	// Putting the ipv4 address in a ssm parameter.
	_, err = ssmClient.PutParameter(&ssm.PutParameterInput{
		Name:      RefString("DropletIP"),
		Type:      RefString("String"),
		Value:     RefString(droplet.Networks.V4[0].IPAddress),
		Overwrite: RefBool(true),
	})
	if err != nil {
		return err
	}

	// Create MX DNS record in the R53 DNS zone.
	sliceOfStrings := strings.Split(parameterName, "-")
	dnsZoneApex := sliceOfStrings[len(sliceOfStrings)-1]

	ssmOutput, err = ssmClient.GetParameter(&ssm.GetParameterInput{
		Name: RefString("HostedZoneId"),
	})
	if err != nil {
		return err
	}

	params := &route53.ChangeResourceRecordSetsInput{
		ChangeBatch: &route53.ChangeBatch{
			Changes: []*route53.Change{
				{
					Action: RefString("CREATE"),
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
					Action: RefString("CREATE"),
					ResourceRecordSet: &route53.ResourceRecordSet{
						Name: RefString("mail." + dnsZoneApex),
						Type: RefString("A"),
						ResourceRecords: []*route53.ResourceRecord{
							{
								Value: RefString(droplet.Networks.V4[0].IPAddress),
							},
						},
						TTL: aws.Int64(300),
					},
				},
			},
		},
		HostedZoneId: ssmOutput.Parameter.Value,
	}

	_, err = route53Client.ChangeResourceRecordSets(params)
	if err != nil {
		fmt.Println(err)
		return err
	}

	return nil
}

func main() {
	lambda.Start(getIpOfDroplet)
}
