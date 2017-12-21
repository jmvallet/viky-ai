require 'pg'
require 'rainbow'

namespace :db do

  desc 'Restore an environment on the local machine'
  task :restore, [:database_dump, :images] => [:environment] do |t, args|
    check_arguments(args)
    params = extract_params(args)
    puts Rainbow("[#{DateTime.now.strftime("%FT%T")}] Restore database (#{params[:database_dump]})").green
    check_duplicate_db(params)
    create_database(params)
    import_dump(params)
    migrate_data
    clean_private_data(params)
    puts Rainbow("[#{DateTime.now.strftime("%FT%T")}] Restore database: done (#{params[:database]})").green

    puts Rainbow("[#{DateTime.now.strftime("%FT%T")}] Synchronize with NLP").green
    backup_dir = File.join(Rails.root, 'import', 'development')
    unless Dir.exists?(backup_dir)
      puts Rainbow("[#{DateTime.now.strftime("%FT%T")}]   Stash packages from import/ to #{backup_dir}").green
      FileUtils.mkdir backup_dir
      FileUtils.cp(Dir.glob(File.join(Rails.root, 'import', '/*.json')), backup_dir)
    else
      puts Rainbow("[#{DateTime.now.strftime("%FT%T")}]   A stash directory is already present at #{backup_dir} : skipping").green
    end
    config = ActiveRecord::Base.connection_config()
    ActiveRecord::Base.establish_connection(
      adapter: 'postgresql',
      host: params[:host],
      port: params[:port],
      username: params[:username],
      password: params[:password],
      database: params[:database]
    )
    puts Rainbow("[#{DateTime.now.strftime("%FT%T")}]   Start synchronization").green
    Rake::Task['packages:push_all'].invoke
    ActiveRecord::Base.establish_connection(config)
    puts Rainbow("[#{DateTime.now.strftime("%FT%T")}] Synchronize with NLP: done").green

    puts Rainbow("[#{DateTime.now.strftime("%FT%T")}] Import images").green
    if params[:images].present?
      backup_dir = File.join(Rails.root, 'public', 'uploads', 'development')
      unless Dir.exists?(backup_dir)
        puts Rainbow("[#{DateTime.now.strftime("%FT%T")}]   Stash packages from public/uploads to #{backup_dir}").green
        FileUtils.mkdir backup_dir
        FileUtils.mv(Dir.glob(File.join(Rails.root, 'public', 'uploads', 'cache')), backup_dir)
        FileUtils.mv(Dir.glob(File.join(Rails.root, 'public', 'uploads', 'store')), backup_dir)
      else
        puts Rainbow("[#{DateTime.now.strftime("%FT%T")}]   A stash directory is already present at #{backup_dir}: skipping").green
      end
      `tar xf #{params[:images]} -C #{Rails.root}/..`
    else
      puts Rainbow("[#{DateTime.now.strftime("%FT%T")}]   No images archive found: reset values").green
      conn = PG.connect(host: params[:host],
                        port: params[:port],
                        dbname: params[:database],
                        user: params[:username],
                        password: params[:password]
      )
      conn.exec("UPDATE users SET image_data=NULL")
      conn.exec("UPDATE agents SET image_data=NULL")
    end
    puts Rainbow("[#{DateTime.now.strftime("%FT%T")}] Import images: done").green
  end


  private

    def check_arguments(args)
      abort Rainbow("[#{DateTime.now.strftime("%FT%T")}] Need database dump file path").yellow unless args.database_dump.present?
    end

    def check_duplicate_db(params)
      is_db_already_present = false
      conn = PG.connect(host: params[:host],
                        port: params[:port],
                        dbname: 'postgres',
                        user: params[:username],
                        password: params[:password]
      )
      conn.exec("SELECT 1 as is_present FROM pg_database WHERE datname='#{params[:database]}'") do |result|
        is_db_already_present = result.field_values('is_present')[0] == '1'
      end
      if is_db_already_present
        abort Rainbow("[#{DateTime.now.strftime("%FT%T")}] Already a database with this name. To drop it use: dropdb -h #{params[:host]} -U #{params[:username]} #{params[:database]}").yellow
      end
    end

    def extract_params(args)
      config = Rails.configuration.database_configuration
      {
        database_dump: args.database_dump,
        host: config[Rails.env]['host'],
        username: config[Rails.env]['username'],
        password: config[Rails.env]['password'],
        port: config[Rails.env]['port'],
        database: 'voqalapp_' + args.database_dump.split('_')[1].tr('-', '_').downcase,
        images: args.images
      }
    end

    def create_database(params)
      conn = PG.connect(host: params[:host],
                        port: params[:port],
                        dbname: 'postgres',
                        user: params[:username],
                        password: params[:password]
      )
      conn.exec("CREATE DATABASE #{params[:database]}")
    end

    def import_dump(params)
      if params[:database_dump].end_with?('.gz')
        `gunzip -c #{params[:database_dump]} | sed 's/OWNER TO superman/OWNER TO #{params[:username]}/ig' | psql -h #{params[:host]} -p #{params[:port]} -U #{params[:username]} #{params[:database]}`
      else
        `psql -h #{params[:host]} -p #{params[:port]} -U #{params[:username]} #{params[:database]} < sed 's/OWNER TO superman/OWNER TO #{params[:username]}/ig' #{params[:database_dump]}`
      end
    end

  def migrate_data
    Rake::Task["db:migrate"].invoke
  end

  def clean_private_data(params)
    conn = PG.connect(host: params[:host],
                      port: params[:port],
                      dbname: params[:database],
                      user: params[:username],
                      password: params[:password]
    )
    conn.exec("UPDATE users SET encrypted_password='$2a$11$WAjRIEDeSHJOzWsLQz.l/OcEUdtlfvvkpz/bW8WYF3r/79sL.yM2S'")
    conn.exec("UPDATE users SET email=CONCAT('login_as_', email)")
  end
end
