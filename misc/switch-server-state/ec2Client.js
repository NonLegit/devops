const  { EC2Client } = require( "@aws-sdk/client-ec2");
const ec2Client = new EC2Client({ region: 'us-east-1' });
module.exports = { ec2Client };
