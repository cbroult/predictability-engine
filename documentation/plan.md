# Plan / TODO

## Sample Data

* Move the sample data files to a sub folder
* Modify the report generation so the generated reports are stored in a folder relative to the sample data file
* Add a command line option to specify the output folder for generated reports
* Add a rake command that generates the reports for all sample data files
* Add a git pre-commit hook to run that rake task and add the generated reports to the commit
* Add a PNG report format
* Reference the large sample data PNG file in the README to support the tool documentation and make a strong statement about the tool capabilities

## CFD

* Improve the x-axis as follows
* A marker should be present for each of the days. Please generate scenarios to handle various cases (e.g., too many days which makes that impractical)
* The marker should be a vertical line smaller than the one for days which have a labeled value
* Make sure the last day has a label.
* Please generate scenarios to handle the labeling of the vertical lines corresponding to the confidence intervals. Those should be labeled with a date. However the scenarios should handle various cases where the intervals may be very close making it difficult to label the vertical lines. 

## Cycle Time Scatter Plot

Please modify the dotted lines so they can be distinguished not only via their color. Different style like dot-dash-dot, but also via their thickness. Additionally, consider using different line widths to further differentiate the lines.

## Logging

* Please add logging to the tool to control the console output and to a log file.
* Please ensure that the logging level can be configured via command line options.
* Please implement a mechanism to rotate log files to prevent them from growing indefinitely.
* Please consider adding a feature to log only errors and warnings by default, and allow for more verbose logging when needed.
* Please implement a logging format that includes timestamp, log level, and log message.
* Any  console output should occur via the logging mechanism
* The console output should be user-friendly and not too verbose by default
* It format is specically tailored for the human eye
* The file logging should be more verbose and include more information and be machine-readable


