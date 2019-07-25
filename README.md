# DB2Scripts
Scripts used to manage Db2 LUW databases
These scripts expect a file structure like
<pre>
---- scripts
 |
  ---sql
</pre>
  i.e. a scripts directory and a sql directory created at the same level in a file system
  
  This is required as the scripts will use relative directory structures to find files. All .sql files should be placed in the sql directory and all other files placed in the scripts directory

As well these scripts generattly will need the use of commonFunctions.pm which is available in the commonFiles (https://github.com/anozdba/commonFiles) repository and this packahe should be placed in the same directory as the script
