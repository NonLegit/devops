package main

import (
	"context"
	"fmt"

	"github.com/aws/aws-lambda-go/cfn"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/route53domains"
)

func checkDomain(ctx context.Context, request cfn.Event) (physicalResourceID string, data map[string]interface{}, err error) {

	if request.RequestType == cfn.RequestDelete {
		return request.PhysicalResourceID, map[string]interface{}{}, nil
	}

	sess := session.Must(session.NewSession())
	r53Client := route53domains.New(sess)

	domains, err := r53Client.ListDomains(nil)
	if err != nil {
		return request.PhysicalResourceID, map[string]interface{}{}, err
	}

	for _, domain := range domains.Domains {
		if *domain.DomainName == request.ResourceProperties["DomainToCheck"] {
			return request.PhysicalResourceID, map[string]interface{}{}, nil
		}
	}

	fmt.Println("nonexistent domain")
	return request.PhysicalResourceID, map[string]interface{}{}, fmt.Errorf("nonexistent domain")
}

func main() {
	lambda.Start(cfn.LambdaWrap(checkDomain))
}
