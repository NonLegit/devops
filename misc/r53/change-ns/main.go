package main

import (
	"context"
	"fmt"

	"github.com/aws/aws-lambda-go/cfn"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/route53domains"
)

func RefString(v string) *string { return &v }

func changeNSOfDomain(ctx context.Context, request cfn.Event) (physicalResourceID string, data map[string]interface{}, err error) {

	if request.RequestType == cfn.RequestDelete {
		return request.PhysicalResourceID, map[string]interface{}{}, nil
	}

	sess := session.Must(session.NewSession())
	r53Client := route53domains.New(sess)

	nameServers := []*route53domains.Nameserver{}

	listOfNameServers, ok := request.ResourceProperties["NameServers"].([]interface{})
	if !ok {
		return request.PhysicalResourceID, map[string]interface{}{}, fmt.Errorf("error conversion")
	}

	for _, ns := range listOfNameServers {
		nameServers = append(nameServers, &route53domains.Nameserver{
			Name: RefString(ns.(string)),
		})
	}

	_, err = r53Client.UpdateDomainNameservers(&route53domains.UpdateDomainNameserversInput{
		DomainName:  RefString(request.ResourceProperties["Domain"].(string)),
		Nameservers: nameServers,
	})

	if err != nil {
		return request.PhysicalResourceID, map[string]interface{}{}, err
	}

	return request.PhysicalResourceID, map[string]interface{}{}, nil
}

func main() {
	lambda.Start(cfn.LambdaWrap(changeNSOfDomain))
}
