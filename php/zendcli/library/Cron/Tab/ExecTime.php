<?php

require_once('Zend/Date.php');

/*
The format of a cron command is very much the V7 standard, with a number of upward-compatible extensions. Each line has five time and date fields, followed by a user name if this is the system crontab file, followed by a command. Commands are executed by cron(8) when the minute, hour, and month of year fields match the current time, and at least one of the two day fields (day of month, or day of week) match the current time (see "Note" below). Note that this means that non-existent times, such as "missing hours" during daylight savings conversion, will never match, causing jobs scheduled during the "missing times" not to be run. Similarly, times that occur more than once (again, during daylight savings conversion) will cause matching jobs to be run twice.

cron(8) examines cron entries once every minute.

The time and date fields are:

    field allowed values
    -----

    --------------

    minute

    0-59

    hour

    0-23

    day of month

    1-31

    month

    1-12 (or names, see below)

    day of week

    0-7 (0 or 7 is Sun, or use names)
A field may be an asterisk (*), which always stands for "first-last".

Ranges of numbers are allowed. Ranges are two numbers separated with a hyphen. The specified range is inclusive. For example, 8-11 for an "hours" entry specifies execution at hours 8, 9, 10 and 11.

Lists are allowed. A list is a set of numbers (or ranges) separated by commas. Examples: "1,2,5,9", "0-4,8-12".
*/
//Step values can be used in conjunction with ranges. Following a range with "<number>" specifies skips of the number's value through the range. For example, "0-23/2" can be used in the hours field to specify command execution every other hour (the alternative in the V7 standard is "0,2,4,6,8,10,12,14,16,18,20,22"). Steps are also permitted after an asterisk, so if you want to say "every two hours", just use "*/2".
/*
Names can also be used for the "month" and "day of week" fields. Use the first three letters of the particular day or month (case doesn't matter). Ranges or lists of names are not allowed.

The "sixth" field (the rest of the line) specifies the command to be run. The entire command portion of the line, up to a newline or % character, will be executed by /bin/sh or by the shell specified in the SHELL variable of the cronfile. Percent-signs (%) in the command, unless escaped with backslash (\), will be changed into newline characters, and all data after the first % will be sent to the command as standard input.

Note: The day of a command's execution can be specified by two fields - day of month, and day of week. If both fields are restricted (ie, aren't *), the command will be run when either field matches the current time. For example,
"30 4 1,15 * 5" would cause a command to be run at 4:30 am on the 1st and 15th of each month, plus every Friday.
 */

class Cron_Tab_ExecTime {
    protected $minutes = array();
    protected $hours = array();
    protected $daysofmonth = array();
    protected $months = array();
    protected $daysofweek = array();

    public function __construct($crontabtimestring){
        $this->set($crontabtimestring);
    }

    public function set($crontabtimestring){
        $elements = preg_split('/\s+/', $crontabtimestring);

        $this->setMinute($elements[0]);
        $this->setHour($elements[1]);
        $this->setDayOfMonth($elements[2]);
        $this->setMonth($elements[3]);
        $this->setDayOfWeek($elements[4]);
    }
    /**
     * must be a number between 0 and 59
     * or a range like 0-59 or 0,1,2,3 or 0-59/4 for every 4th minute
     * or * for every minute
     */
    public function setMinute($minute){
        $this->minutes = $this->convertToList($minute, range(0, 59));
    }
    protected function isMinuteRestricted(){
        return count($this->minutes)!=60;
    }
    protected function doesMinuteMatch($min){
        if(in_array($min, $this->minutes)){
            return true;
        }
        return false;
    }

    public function setHour($hour){
        $this->hours = $this->convertToList($hour, range(0, 23));
    }
    protected function isHourRestricted(){
        return count($this->hours)!=24;
    }
    protected function doesHourMatch($hour){
        if(in_array($hour, $this->hours)){
            return true;
        }
        return false;
    }

    public function setDayOfMonth($dayofmonth){
        $this->daysofmonth = $this->convertToList($dayofmonth, range(1, 31));
    }
    protected function isDayOfMonthRestricted(){
        return count($this->daysofmonth)!=31;
    }
    protected function doesDayOfMonthMatch($dom){
        if(in_array($dom, $this->daysofmonth)){
            return true;
        }
        return false;
    }


    public function setMonth($month){
        $months = array('jan'=>1, 'feb'=>2,  'mar'=>3,  'apr'=>4,
                        'mai'=>5, 'jun'=>6,  'jul'=>7,  'aug'=>8,
                        'sep'=>9, 'oct'=>10, 'nov'=>11, 'dec'=>12
                       );
        $this->months = $this->convertToList($month, $months);
    }
    protected function isMonthRestricted(){
        return count($this->months)!=12;
    }
    protected function doesMonthMatch($month){
        if(in_array($month, $this->months)){
            return true;
        }
        return false;
    }

    public function setDayOfWeek($dayofweek){
        $days = array('sun'=>0,'mon'=>1,'tue'=>2,'wed'=>3,
                      'thu'=>4,'fri'=>5,'sat'=>6,'sun'=>7
                     );
        $this->daysofweek = $this->convertToList($dayofweek, $days);
    }
    protected function isDayOfWeekRestricted(){
        return count($this->daysofweek)<=6;
    }
    protected function doesDayOfWeekMatch($dow){
        if(in_array($dow, $this->daysofweek)){
            return true;
        }
        return false;
    }



    public function doesMatch(Zend_Date $date){

        $minute = $date->get(Zend_Date::MINUTE_SHORT);
        $hour   = $date->get(Zend_Date::HOUR_SHORT);
        $month  = $date->get(Zend_Date::MONTH_SHORT);
        $dow    = $date->get(Zend_Date::WEEKDAY_DIGIT);
        $dom    = $date->get(Zend_Date::DAY_SHORT);
        if($this->doesMinuteMatch($minute) &&
           $this->doesHourMatch($hour) &&
           $this->doesMonthMatch($month)
          ){
            if($this->isDayOfMonthRestricted() && $this->isDayOfWeekRestricted()){
                return $this->doesDayOfMonthMatch($dom) || $this->doesDayOfWeekMatch($dow);
            }
            else if($this->isDayOfMonthRestricted()){
                return $this->doesDayOfMonthMatch($dom);
            }
            else if($this->isDayOfWeekRestricted()){
                return $this->doesDayOfWeekMatch($dow);
            }
            return true;
        }
        return false;

    }



    protected function convertToList($element, $values){
        $finalvalues = array();
        if($element == '*'){
            $finalvalues = array_values($values);
        }
        else{
            $elements = explode(",", $element);
            foreach($elements as $element){
                $skips = 0;
                $rangestart=null;$rangeend=null;
                if($element == "*"){
                    $finalvalues = array_values($values);
                    break;
                }
                else if(($pos=strpos($element, '/'))!==false){
                    $skips   = intval(substr($element, $pos+1));
                    $element = substr($element, 0, $pos);
                }
                if(($pos=strpos($element,'-'))!==false){
                    $rangestart = substr($element, 0, $pos);
                    $rangeend   = substr($element, $pos+1);
                }
                else if($element == "*"){
                    reset($values);
                    $rangestart = current($values);
                    $rangeend   = end($values);
                }
                else{
                    $rangestart = $rangeend = $element;
                }

                if($rangestart==$rangeend){
                    $finalvalues[] = $rangestart;
                }
                else{
                    $finalvalues = array_merge($finalvalues,
                                               $this->getRange($rangestart, $rangeend, $skips, $values)
                                              );
                }
            }
        }
        return $finalvalues;
    }

    protected function getRange($start, $end, $skips, $values){
        $range = array();

        $startkey = isset($values[$start]) ? $start : array_search($start, $values);
        $endkey   = isset($values[$end]) ? $end : array_search($end, $values);

        $startfound   = false;
        $endfound     = false;
        $currentskips = $skips;
        $valuecnt = count($values);
        do{
            foreach($values as $key => $value){
                if($key == $startkey){
                    $startfound = true;
                }

                if(($currentskips == $skips || $currentskips == 0) && ($startfound && !$endfound)){
                    $range[] = $value;
                }

                if($key == $endkey){
                    $endfound   = true;
                }

                $currentskips--;
                $valuecnt--;

                if($currentskips<=0){
                    $currentskips = $skips;
                }
            }
        }while($endfound == false && $valuecnt>0);

        return array_unique($range);
    }

}
