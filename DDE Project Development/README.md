### Scenario: 
A team currently working in an software development project where task will be broken down into a number of sprints. As the project is scaling up, the leader requires creating a dashboard to track the development progress of these software packages and the workload of team members.

### Data transformation:
These data are currently stored in BigQuery. While the raw data of each member's workload are already cleaned and ready for use, further transformation are still needed for the data of software packages' status in order to create a usable dashboard.
(Screenshot 2412)

+ Transformation script
(Screenshot 2415)

### Data modelling:
Since star schema design are highly relevant to developing Power BI models especially when many fact tables sharing the same dimensions, Power Query Editor has been used to created different dimension tables from two fact tables (Package Status and Jira Ticket) and create relationships among them.
(Screenshot 2417)

### Using DAX:
DAX is used to create various measures and custom dimensions in my model, for example:
+ Create string aggregation

```
Aggregate Package = 
  CONCATENATEX(
    VALUES('Package Status'[Package Name]),
    'Package Status'[Package Name],", ")
```
+ Create aggregation in a filtered context

```
Average Hit Target Rate = 
VAR HitTargets = 
    CALCULATE(
        DISTINCTCOUNT('Package Status Compare'[Package Name]),
        'Package Status Compare'[Reach Goal Flag]=True)

VAR TotalPackages = DISTINCTCOUNT('Package Status Compare'[Package Name])

RETURN DIVIDE(HitTargets, TotalPackages) + 0
```

+ Create custom dimension
```
Cognos or New to Looker = IF('Package Status Compare'[Is Cognos]="Y", "Cognos", "New to Looker")
```
