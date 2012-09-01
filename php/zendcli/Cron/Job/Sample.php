<?php
require_once('Cron/Job.php');

class Cron_Job_Sample extends Cron_Job{

	public $_singleinstance = true;

    protected $name = 'Sample';

    public function run(){
    	var_dump("Sample Cronjob is executing");
    }
}